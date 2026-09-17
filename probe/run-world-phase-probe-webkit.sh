#!/usr/bin/env bash
set -u
LAB_ROOT="${GITHUB_WORKSPACE:-$(pwd)}"
WORK="${RUNNER_TEMP:-/tmp}/kelo-world-phase-probe"
ART="$LAB_ROOT/probe-artifacts"
RUNNER="$LAB_ROOT/probe/world-phase-probe-webkit.mjs"
TARGET="ea0dc18a55007351cfdccb37fda5ed1faca9eac3"
mkdir -p "$ART"
rm -rf "$WORK"
git clone --quiet https://github.com/kelffren/gemini.git "$WORK"
cd "$WORK"
git checkout --detach -q "$TARGET"
npm install --no-audit --no-fund >/tmp/kelo-phase-npm.log 2>&1 || { cat /tmp/kelo-phase-npm.log; exit 2; }
npx playwright install webkit --with-deps

python3 - <<'PY'
from pathlib import Path
p=Path('src/studio/integration/live-studio-controller.mjs')
s=p.read_text()
def once(old,new):
    global s
    if old not in s:
        raise SystemExit(f'MISSING_MARKER: {old[:90]}')
    s=s.replace(old,new,1)

once("function pause(root,ms){return new Promise(resolve=>(root.setTimeout||setTimeout)(resolve,ms));}",
     "function pause(root,ms){return new Promise(resolve=>(root.setTimeout||setTimeout)(resolve,ms));}\nfunction __labPhase(root,name){try{root.fetch?.('/__kelo_phase/'+encodeURIComponent(name),{cache:'no-store'}).catch(()=>{});}catch{}}")
once("  if(isPhone(root))await pause(root,40);\n  const {",
     "  __labPhase(root,'CHROME_READY');\n  if(isPhone(root))await pause(root,40);\n  __labPhase(root,'RUNTIME_START');\n  const {")
once("  }=await loadLiveStudioRuntime(root);\n  if(root.KELO_WORLD_LAUNCH_ABORTED)",
     "  }=await loadLiveStudioRuntime(root);\n  __labPhase(root,'RUNTIME_DONE');\n  if(root.KELO_WORLD_LAUNCH_ABORTED)")
once("  const draft=await ensureDraft(root,actorId);if(root.KELO_WORLD_LAUNCH_ABORTED)",
     "  __labPhase(root,'DRAFT_START');\n  const draft=await ensureDraft(root,actorId);\n  __labPhase(root,'DRAFT_DONE');\n  if(root.KELO_WORLD_LAUNCH_ABORTED)")
once("  const {bootKeloStudio}=await import(`../studio-entry.mjs?v=${BUILD}`);\n  if(root.KELO_WORLD_LAUNCH_ABORTED)",
     "  __labPhase(root,'STUDIO_ENTRY_IMPORT_START');\n  const {bootKeloStudio}=await import(`../studio-entry.mjs?v=${BUILD}`);\n  __labPhase(root,'STUDIO_ENTRY_IMPORT_DONE');\n  if(root.KELO_WORLD_LAUNCH_ABORTED)")
once("  const studio=await bootKeloStudio({mode:'world',actorId,root});if(root.KELO_WORLD_LAUNCH_ABORTED)",
     "  __labPhase(root,'STUDIO_BOOT_START');\n  const studio=await bootKeloStudio({mode:'world',actorId,root});\n  __labPhase(root,'STUDIO_BOOT_DONE');\n  if(root.KELO_WORLD_LAUNCH_ABORTED)")
once("  const creator=createCreatorActions(studio.kernel),prefabLibrary=createCreatorPrefabLibrary({kernel:studio.kernel,store:studio.store,tool:studio.tools.prefabStamp,ownerId:actorId});",
     "  __labPhase(root,'CREATOR_SERVICES_START');\n  const creator=createCreatorActions(studio.kernel),prefabLibrary=createCreatorPrefabLibrary({kernel:studio.kernel,store:studio.store,tool:studio.tools.prefabStamp,ownerId:actorId});\n  __labPhase(root,'CREATOR_SERVICES_DONE');")
once("    inputLockToken=root.KeloInputLocks.acquire('kelo-studio',{kind:'creator-session',draftId});",
     "    __labPhase(root,'SESSION_WIRING_START');\n    inputLockToken=root.KeloInputLocks.acquire('kelo-studio',{kind:'creator-session',draftId});\n    __labPhase(root,'INPUT_LOCK_DONE');")
once("    cameraController=createStudioCameraController({root,isUi:isStudioUi,onNavigateStart:cancelForCamera,onPinchStart:payload=>mode==='select'?false:beginPinchScale(payload),onPinchMove:movePinchScale,onPinchEnd:payload=>{void guarded(()=>endPinchScale(payload));}});",
     "    __labPhase(root,'CAMERA_START');\n    cameraController=createStudioCameraController({root,isUi:isStudioUi,onNavigateStart:cancelForCamera,onPinchStart:payload=>mode==='select'?false:beginPinchScale(payload),onPinchMove:movePinchScale,onPinchEnd:payload=>{void guarded(()=>endPinchScale(payload));}});\n    __labPhase(root,'CAMERA_DONE');")
once("    detachPointer=attachStudioPointerInput({element:root.document,router:studio.kernel.input,toWorld:(x,y)=>cameraController.toWorld(x,y),capture:true,stopPropagation:true,shouldHandle:e=>running&&!playing&&!isStudioUi(e)});",
     "    __labPhase(root,'POINTER_START');\n    detachPointer=attachStudioPointerInput({element:root.document,router:studio.kernel.input,toWorld:(x,y)=>cameraController.toWorld(x,y),capture:true,stopPropagation:true,shouldHandle:e=>running&&!playing&&!isStudioUi(e)});\n    __labPhase(root,'POINTER_DONE');")
once("    shell=createStudioLiveShell({host:root.document.body,reuse:phoneShell&&!!root.document.getElementById('kelo-studio-live')?.querySelector?.('.ks-top'),assets:phoneShell?phoneSeedAssets(allAssets()):allAssets(),",
     "    __labPhase(root,'FINAL_SHELL_START');\n    shell=createStudioLiveShell({host:root.document.body,reuse:phoneShell&&!!root.document.getElementById('kelo-studio-live')?.querySelector?.('.ks-top'),assets:phoneShell?phoneSeedAssets(allAssets()):allAssets(),")
once("    try{root.document.getElementById('kelo-world-launch-curtain')?.remove();}catch{}",
     "    __labPhase(root,'FINAL_SHELL_DONE');\n    try{root.document.getElementById('kelo-world-launch-curtain')?.remove();}catch{}")
once("selectionUnsub=studio.kernel.selection.onChange(updateShell);updateShell();",
     "selectionUnsub=studio.kernel.selection.onChange(updateShell);__labPhase(root,'UPDATE_SHELL_START');updateShell();__labPhase(root,'UPDATE_SHELL_DONE');")
once("      const immediate=paintSeed('seed',{openSheet:true});",
     "      __labPhase(root,'PHONE_SEED_START');\n      const immediate=paintSeed('seed',{openSheet:true});\n      __labPhase(root,'PHONE_SEED_DONE');")
once("    await yieldLiveMount(root);\n    if(root.KELO_WORLD_LAUNCH_ABORTED)",
     "    __labPhase(root,'YIELD_START');\n    await yieldLiveMount(root);\n    __labPhase(root,'YIELD_DONE');\n    if(root.KELO_WORLD_LAUNCH_ABORTED)")
once("    if(shell?.root?.dataset)delete shell.root.dataset.keloWorldLoading;",
     "    __labPhase(root,'INTERACTIVE_START');\n    if(shell?.root?.dataset)delete shell.root.dataset.keloWorldLoading;")
once("    active=Object.freeze(liveSession);root.document.body.classList.add('kelo-studio-active');toast(root,'Kelo Studio Creator V1.8 activo');",
     "    active=Object.freeze(liveSession);root.document.body.classList.add('kelo-studio-active');toast(root,'Kelo Studio Creator V1.8 activo');__labPhase(root,'INTERACTIVE_DONE');")
once("    return active;",
     "    __labPhase(root,'RETURN_ACTIVE');\n    return active;")
p.write_text(s)
PY

mkdir -p scripts
cp "$RUNNER" scripts/__world-phase-probe-webkit.mjs
python3 -m http.server 4173 --bind 127.0.0.1 >"$ART/http.log" 2>&1 & server=$!
for _ in $(seq 1 30); do curl -fsS http://127.0.0.1:4173/index.html >/dev/null 2>&1 && break; sleep .2; done
timeout 55s node scripts/__world-phase-probe-webkit.mjs --sha="$TARGET" --out="$ART" --base=http://127.0.0.1:4173/ | tee "$ART/run-log.txt"
rc=${PIPESTATUS[0]}
kill "$server" 2>/dev/null || true
wait "$server" 2>/dev/null || true
echo "rc=$rc" > "$ART/result.txt"
cat "$ART"/phase-*.json 2>/dev/null || true
exit 0
