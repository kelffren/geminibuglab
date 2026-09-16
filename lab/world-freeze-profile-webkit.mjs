import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import {createRequire} from 'node:module';

const requireFromRepo=createRequire(path.join(process.cwd(),'package.json'));
let webkit;
try{({webkit}=requireFromRepo('@playwright/test'));}
catch(error){console.error('LAB_PLAYWRIGHT_UNAVAILABLE',error?.message||error);process.exit(125);}

const args=Object.fromEntries(process.argv.slice(2).map(raw=>{const clean=raw.replace(/^--/,'');const i=clean.indexOf('=');return i<0?[clean,'1']:[clean.slice(0,i),clean.slice(i+1)];}));
const base=String(args.base||'http://127.0.0.1:4173/');
const out=path.resolve(args.out||'lab-artifacts');
const sha=String(args.sha||'unknown');
fs.mkdirSync(out,{recursive:true});
const report={schema:5,engine:'webkit',sha,startedAt:new Date().toISOString(),result:'RUNNING',reason:null,milestones:[],lastResource:null,resources:[],console:[],pageErrors:[],requestFailures:[],crashed:false};
const mark=(name,data={})=>{const row={at:new Date().toISOString(),name,...data};report.milestones.push(row);console.log('LAB_MILESTONE',name,JSON.stringify(data));};
const save=()=>fs.writeFileSync(path.join(out,`webkit-world-${sha.slice(0,12)}.json`),JSON.stringify(report,null,2));
const timeout=(promise,ms,label)=>Promise.race([promise,new Promise((_,reject)=>setTimeout(()=>reject(new Error(`${label}_TIMEOUT_${ms}`)),ms))]);
const target=()=>{const u=new URL(base);u.searchParams.set('aiGuest','1');u.searchParams.set('creators','1');u.searchParams.set('freezeLab','1');u.searchParams.set('recoveryLab','1');u.searchParams.set('recoveryFlow','world-open');u.searchParams.set('bug','BUG-0003');return u.href;};

let browser,context,page,traceStarted=false;
try{
  browser=await webkit.launch({headless:true});
  context=await browser.newContext({viewport:{width:390,height:844},userAgent:'Mozilla/5.0 (iPhone; CPU iPhone OS 26_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Mobile/15E148 Safari/604.1',isMobile:true,hasTouch:true,deviceScaleFactor:2});
  await context.tracing.start({screenshots:true,snapshots:true,sources:true});traceStarted=true;
  page=await context.newPage();
  page.setDefaultTimeout(15000);
  page.on('crash',()=>{report.crashed=true;mark('PAGE_CRASH');});
  page.on('pageerror',e=>report.pageErrors.push(String(e?.message||e).slice(0,800)));
  page.on('console',m=>{if(['error','warning'].includes(m.type()))report.console.push({type:m.type(),text:m.text().slice(0,900)});});
  page.on('requestfailed',r=>{if(report.requestFailures.length<100)report.requestFailures.push({url:r.url(),error:String(r.failure()?.errorText||'REQUEST_FAILED').slice(0,300)});});
  page.on('requestfinished',r=>{const url=r.url();if(/\/src\/(studio|creators|world)\//.test(url)){report.lastResource=url.split('?')[0];if(report.resources.length<500)report.resources.push(report.lastResource);}});

  mark('NAVIGATE',{url:target()});
  await page.goto(target(),{waitUntil:'domcontentloaded',timeout:30000});
  mark('DOM_CONTENT_LOADED');

  await timeout(page.evaluate(()=>{
    const original=window.KELO_ADMIN_KEYS||{};
    window.__KELO_LAB_ORIGINAL_ADMIN_KEYS=original;
    const facade={};
    for(const key of Reflect.ownKeys(original)){
      try{const value=original[key];facade[key]=typeof value==='function'?value.bind(original):value;}catch{}
    }
    facade.can=()=>true;
    facade.playerId=()=>{
      try{return original.playerId?.()||window.keloNet?.playerKey||window.localPlayer?.id||'kelo_freeze_lab_admin';}
      catch{return window.keloNet?.playerKey||window.localPlayer?.id||'kelo_freeze_lab_admin';}
    };
    window.KELO_ADMIN_KEYS=facade;
    return {can:window.KELO_ADMIN_KEYS.can('world.edit'),actor:window.KELO_ADMIN_KEYS.playerId()};
  }),2500,'ADMIN_LAB_FACADE');
  mark('LAB_ADMIN_AUTHORIZED');

  mark('WORLD_OWNER_OPEN_REQUEST');
  await timeout(page.evaluate(()=>{
    window.__KELO_LAB_WORLD_OPEN={state:'scheduled',error:null};
    Promise.resolve().then(()=>import('./src/creators/workspaces/world-workspace.mjs')).then(mod=>{
      if(typeof mod.createWorldWorkspaceManifest!=='function')throw new Error('WORLD_WORKSPACE_FACTORY_MISSING');
      const manifest=mod.createWorldWorkspaceManifest();
      window.__KELO_LAB_WORLD_OPEN.state='invoked';
      return manifest.open({root:window});
    }).then(()=>{window.__KELO_LAB_WORLD_OPEN.state='resolved';}).catch(error=>{
      window.__KELO_LAB_WORLD_OPEN.state='rejected';
      window.__KELO_LAB_WORLD_OPEN.error=String(error?.stack||error?.message||error).slice(0,1800);
      console.error('[World Freeze Lab] owner open rejected',error);
    });
    return true;
  }),5000,'WORLD_OWNER_SCHEDULE');
  mark('WORLD_OWNER_OPEN_SCHEDULED');

  await page.waitForFunction(()=>['resolved','rejected'].includes(window.__KELO_LAB_WORLD_OPEN?.state),null,{timeout:35000});
  const owner=await timeout(page.evaluate(()=>window.__KELO_LAB_WORLD_OPEN||null),2000,'OWNER_STATE');
  report.ownerOpen=owner;
  if(owner?.state!=='resolved')throw new Error(`WORLD_OWNER_REJECTED:${owner?.error||'UNKNOWN'}`);
  mark('WORLD_OWNER_RESOLVED');

  const shell=page.locator('#kelo-studio-live');
  if(await shell.count())mark('WORLD_SHELL_MOUNTED');else mark('WORLD_SHELL_NOT_FOUND');

  for(let i=1;i<=6;i++){
    await new Promise(r=>setTimeout(r,650));
    const t0=Date.now();
    await timeout(page.evaluate(()=>({ready:document.readyState,now:performance.now(),open:window.__KELO_LAB_WORLD_OPEN||null})),2200,`PING_${i}`);
    const ms=Date.now()-t0;mark(`PING_${i}`,{ms});if(ms>1800)throw new Error(`EVENT_LOOP_FREEZE_${ms}`);
  }
  if(report.crashed)throw new Error('PAGE_CRASH');
  try{report.recovery=await timeout(page.evaluate(()=>window.KELO_RECOVERY_MESH?.report?.()||window.KELO_FREEZE_LOCATOR?.report?.()||window.KELO_WORLD_SURGERY?.flight||null),2200,'RECOVERY_REPORT');}catch{}
  report.result='PASS';mark('PROFILE_PASS');
}catch(error){
  report.result='FAIL';report.reason=String(error?.stack||error?.message||error).slice(0,3200);mark('PROFILE_FAIL',{reason:String(error?.message||error),lastResource:report.lastResource});
  try{report.ownerOpen=await timeout(page?.evaluate(()=>window.__KELO_LAB_WORLD_OPEN||null),900,'OWNER_OPEN_FAIL_REPORT');}catch{}
  try{report.recovery=await timeout(page?.evaluate(()=>window.KELO_RECOVERY_MESH?.report?.()||window.KELO_FREEZE_LOCATOR?.report?.()||window.KELO_WORLD_SURGERY?.flight||null),900,'RECOVERY_FAIL_REPORT');}catch{}
  try{await timeout(page?.screenshot({path:path.join(out,`webkit-failure-${sha.slice(0,12)}.png`),fullPage:true}),2500,'SCREENSHOT');}catch{}
}finally{
  if(traceStarted&&context){try{await timeout(context.tracing.stop({path:path.join(out,`webkit-trace-${sha.slice(0,12)}.zip`)}),5000,'TRACE_STOP');}catch{}}
  report.finishedAt=new Date().toISOString();try{save();}catch{}
  try{await timeout(context?.close(),2500,'CONTEXT_CLOSE');}catch{}
  try{await timeout(browser?.close(),2500,'BROWSER_CLOSE');}catch{}
}
process.exit(report.result==='PASS'?0:1);
