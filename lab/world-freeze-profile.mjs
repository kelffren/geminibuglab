import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import {createRequire} from 'node:module';

const requireFromRepo=createRequire(path.join(process.cwd(),'package.json'));
let chromium;
try{({chromium}=requireFromRepo('@playwright/test'));}
catch(error){console.error('LAB_PLAYWRIGHT_UNAVAILABLE',error?.message||error);process.exit(125);}

const args=Object.fromEntries(process.argv.slice(2).map(raw=>{const clean=raw.replace(/^--/,'');const i=clean.indexOf('=');return i<0?[clean,'1']:[clean.slice(0,i),clean.slice(i+1)];}));
const base=String(args.base||'http://127.0.0.1:4173/');
const out=path.resolve(args.out||'lab-artifacts');
const sha=String(args.sha||'unknown');
fs.mkdirSync(out,{recursive:true});
const report={schema:1,sha,startedAt:new Date().toISOString(),result:'RUNNING',reason:null,milestones:[],lastResource:null,resources:[],console:[],pageErrors:[],requestFailures:[],crashed:false};
const mark=(name,data={})=>{const row={at:new Date().toISOString(),name,...data};report.milestones.push(row);console.log('LAB_MILESTONE',name,JSON.stringify(data));};
const save=()=>fs.writeFileSync(path.join(out,`world-${sha.slice(0,12)}.json`),JSON.stringify(report,null,2));
const timeout=(promise,ms,label)=>Promise.race([promise,new Promise((_,reject)=>setTimeout(()=>reject(new Error(`${label}_TIMEOUT_${ms}`)),ms))]);
const target=()=>{const u=new URL(base);u.searchParams.set('aiGuest','1');u.searchParams.set('creators','1');u.searchParams.set('freezeLab','1');u.searchParams.set('recoveryLab','1');u.searchParams.set('recoveryFlow','world-open');u.searchParams.set('bug','BUG-0003');return u.href;};

let browser,context,page,traceStarted=false;
try{
  browser=await chromium.launch({headless:true});
  context=await browser.newContext({viewport:{width:390,height:844},userAgent:'Mozilla/5.0 (iPhone; CPU iPhone OS 26_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Mobile/15E148 Safari/604.1',isMobile:true,hasTouch:true,deviceScaleFactor:2});
  await context.tracing.start({screenshots:true,snapshots:true,sources:true});traceStarted=true;
  page=await context.newPage();
  page.setDefaultTimeout(15000);
  page.on('crash',()=>{report.crashed=true;mark('PAGE_CRASH');});
  page.on('pageerror',e=>report.pageErrors.push(String(e?.message||e).slice(0,600)));
  page.on('console',m=>{if(['error','warning'].includes(m.type()))report.console.push({type:m.type(),text:m.text().slice(0,600)});});
  page.on('requestfailed',r=>{if(report.requestFailures.length<100)report.requestFailures.push({url:r.url(),error:String(r.failure()?.errorText||'REQUEST_FAILED').slice(0,300)});});
  page.on('requestfinished',r=>{const url=r.url();if(/\/src\/(studio|creators|world)\//.test(url)){report.lastResource=url.split('?')[0];if(report.resources.length<300)report.resources.push(report.lastResource);}});

  mark('NAVIGATE',{url:target()});
  await page.goto(target(),{waitUntil:'domcontentloaded',timeout:30000});
  mark('DOM_CONTENT_LOADED');
  let world=page.locator('[data-workspace="world"]').last();
  if(!await world.count()){
    try{await timeout(page.evaluate(async()=>{const mod=await import('./src/creators/ui/creator-hub.mjs');await mod.openCreatorHub?.({root:window});}),6000,'OPEN_HUB');}catch{}
    world=page.locator('[data-workspace="world"]').last();
  }
  await world.waitFor({state:'attached',timeout:18000});
  mark('WORLD_CARD_FOUND');
  await world.click({timeout:8000});
  mark('WORLD_TAP');
  await page.locator('#kelo-studio-live').waitFor({state:'attached',timeout:8000});
  mark('WORLD_SHELL_MOUNTED');

  await page.waitForFunction(()=>{const live=document.getElementById('kelo-studio-live');return !!live&&live.dataset?.keloWorldLoading!=='1'&&!!live.querySelector('.ks-status');},null,{timeout:25000});
  mark('WORLD_READY');
  for(let i=1;i<=3;i++){
    await new Promise(r=>setTimeout(r,700));
    const t0=Date.now();
    await timeout(page.evaluate(()=>({ready:document.readyState,now:performance.now()})),2500,`PING_${i}`);
    const ms=Date.now()-t0;mark(`PING_${i}`,{ms});if(ms>2000)throw new Error(`EVENT_LOOP_FREEZE_${ms}`);
  }
  if(report.crashed)throw new Error('PAGE_CRASH');
  try{report.recovery=await timeout(page.evaluate(()=>window.KELO_RECOVERY_MESH?.report?.()||window.KELO_FREEZE_LOCATOR?.report?.()||null),2500,'RECOVERY_REPORT');}catch{}
  report.result='PASS';mark('PROFILE_PASS');
}catch(error){
  report.result='FAIL';report.reason=String(error?.stack||error?.message||error).slice(0,3000);mark('PROFILE_FAIL',{reason:String(error?.message||error),lastResource:report.lastResource});
  try{await timeout(page?.screenshot({path:path.join(out,`failure-${sha.slice(0,12)}.png`),fullPage:true}),3000,'SCREENSHOT');}catch{}
}finally{
  if(traceStarted&&context){try{await timeout(context.tracing.stop({path:path.join(out,`trace-${sha.slice(0,12)}.zip`)}),5000,'TRACE_STOP');}catch{}}
  report.finishedAt=new Date().toISOString();try{save();}catch{}
  try{await timeout(context?.close(),2500,'CONTEXT_CLOSE');}catch{}
  try{await timeout(browser?.close(),2500,'BROWSER_CLOSE');}catch{}
}
process.exit(report.result==='PASS'?0:1);
