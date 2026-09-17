import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import {createRequire} from 'node:module';

const requireFromRepo=createRequire(path.join(process.cwd(),'package.json'));
const {webkit}=requireFromRepo('@playwright/test');
const args=Object.fromEntries(process.argv.slice(2).map(raw=>{const clean=raw.replace(/^--/,'');const i=clean.indexOf('=');return i<0?[clean,'1']:[clean.slice(0,i),clean.slice(i+1)];}));
const base=String(args.base||'http://127.0.0.1:4173/');
const out=path.resolve(args.out||'probe-artifacts');
const sha=String(args.sha||'unknown');
fs.mkdirSync(out,{recursive:true});
const report={schema:2,engine:'webkit',sha,startedAt:new Date().toISOString(),phases:[],lastPhase:null,lastResource:null,resources:[],console:[],pageErrors:[],owner:null,result:'RUNNING',reason:null};
const save=()=>fs.writeFileSync(path.join(out,`phase-${sha.slice(0,12)}.json`),JSON.stringify(report,null,2));
const timeout=(promise,ms,label)=>Promise.race([promise,new Promise((_,rej)=>setTimeout(()=>rej(new Error(`${label}_TIMEOUT_${ms}`)),ms))]);
let browser,context,page;
try{
  browser=await webkit.launch({headless:true});
  context=await browser.newContext({viewport:{width:390,height:844},userAgent:'Mozilla/5.0 (iPhone; CPU iPhone OS 26_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Mobile/15E148 Safari/604.1',isMobile:true,hasTouch:true,deviceScaleFactor:2});
  page=await context.newPage();
  page.on('request',req=>{
    const u=req.url();
    const m=u.match(/\/__kelo_phase\/([^/?#]+)/);
    if(m){const name=decodeURIComponent(m[1]);report.lastPhase=name;report.phases.push({at:new Date().toISOString(),name});console.log('PHASE',name);save();}
  });
  page.on('requestfinished',req=>{const u=req.url();if(/\/src\/(studio|creators|world)\//.test(u)){report.lastResource=u.split('?')[0];if(report.resources.length<500)report.resources.push(report.lastResource);}});
  page.on('console',msg=>{if(['error','warning'].includes(msg.type()))report.console.push({type:msg.type(),text:msg.text().slice(0,900)});});
  page.on('pageerror',err=>report.pageErrors.push(String(err?.message||err).slice(0,900)));

  // Direct-owner isolation: intentionally do NOT add ?creators=1. That query
  // auto-boots Creator Hub and its avatar/sprite compiler graph in parallel,
  // masking the real World/Studio phase that freezes WebKit.
  const target=new URL(base);
  target.searchParams.set('aiGuest','1');
  target.searchParams.set('freezeLab','1');
  target.searchParams.set('recoveryLab','1');
  target.searchParams.set('recoveryFlow','world-open');
  await page.goto(target.href,{waitUntil:'domcontentloaded',timeout:30000});

  await timeout(page.evaluate(()=>{
    const original=window.KELO_ADMIN_KEYS||{},facade={};
    for(const key of Reflect.ownKeys(original)){try{const value=original[key];facade[key]=typeof value==='function'?value.bind(original):value;}catch{}}
    let actor='kelo_freeze_lab_admin';try{actor=String(original.playerId?.()||window.keloNet?.playerKey||window.localPlayer?.id||actor);}catch{}
    facade.can=()=>true;facade.playerId=()=>actor;window.KELO_ADMIN_KEYS=facade;return actor;
  }),2500,'ADMIN');

  await timeout(page.evaluate(()=>{
    window.__KELO_LAB_WORLD_OPEN={state:'scheduled',error:null};
    Promise.resolve().then(()=>import('./src/creators/workspaces/world-workspace.mjs')).then(mod=>{
      const manifest=mod.createWorldWorkspaceManifest();window.__KELO_LAB_WORLD_OPEN.state='invoked';return manifest.open({root:window});
    }).then(()=>window.__KELO_LAB_WORLD_OPEN.state='resolved').catch(error=>{window.__KELO_LAB_WORLD_OPEN.state='rejected';window.__KELO_LAB_WORLD_OPEN.error=String(error?.stack||error);});
    return true;
  }),3000,'SCHEDULE');
  try{
    await page.waitForFunction(()=>['resolved','rejected'].includes(window.__KELO_LAB_WORLD_OPEN?.state),null,{timeout:35000});
    report.owner=await timeout(page.evaluate(()=>window.__KELO_LAB_WORLD_OPEN),1500,'OWNER');
    report.result=report.owner?.state==='resolved'?'PASS':'FAIL';
    if(report.result==='FAIL')report.reason=report.owner?.error||'OWNER_REJECTED';
  }catch(error){report.result='FREEZE';report.reason=String(error?.message||error);}
}catch(error){report.result='FAIL';report.reason=String(error?.stack||error).slice(0,2400);}
finally{
  report.finishedAt=new Date().toISOString();try{save();}catch{}
  try{await timeout(page?.screenshot({path:path.join(out,`phase-${sha.slice(0,12)}.png`),fullPage:true}),2000,'SCREENSHOT');}catch{}
  try{await timeout(context?.close(),2000,'CONTEXT_CLOSE');}catch{}
  try{await timeout(browser?.close(),2000,'BROWSER_CLOSE');}catch{}
}
console.log(JSON.stringify({result:report.result,lastPhase:report.lastPhase,lastResource:report.lastResource,owner:report.owner,reason:report.reason}));
process.exit(report.result==='PASS'?0:1);
