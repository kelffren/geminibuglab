from pathlib import Path

p=Path('src/studio/studio-entry.mjs')
s=p.read_text()

def once(old,new):
    global s
    if old not in s:
        raise SystemExit(f'MISSING_STUDIO_MARKER: {old[:120]}')
    s=s.replace(old,new,1)

once("async function loadStudioCore(root,phoneBoot){",
     "function __labStudioPhase(root,name){try{root.fetch?.('/__kelo_phase/'+encodeURIComponent(name),{cache:'no-store'}).catch(()=>{});}catch{}}\n\nasync function loadStudioCore(root,phoneBoot){")

steps=[
("  const kernelMod=await import('./core/studio-kernel.mjs');await wait();abort();", "CORE_KERNEL"),
("  const documentMod=await import('./document/world-document.mjs');await wait();abort();", "CORE_DOCUMENT"),
("  const adapterMod=await import('./adapters/kelo-runtime-adapter.mjs');await wait();abort();", "CORE_RUNTIME_ADAPTER"),
("  const seederMod=await import('./adapters/catalog-prefab-seeder.mjs');await wait();abort();", "CORE_PREFAB_SEEDER"),
("  const componentsMod=await import('./components/kelo-components.mjs');await wait();abort();", "CORE_COMPONENTS"),
("  const importerMod=await import('./adapters/current-world-importer.mjs');await wait();abort();", "CORE_CURRENT_IMPORTER"),
("  const previewMod=await import('./render/studio-asset-preview-service.mjs');await wait();abort();", "CORE_ASSET_PREVIEW"),
("  const storeMod=await import('./storage/indexeddb-studio-store.mjs');await wait();abort();", "CORE_INDEXEDDB"),
("  const profilerMod=await import('./performance/studio-profiler.mjs');await wait();abort();", "CORE_PROFILER"),
("  const compilerMod=await import('./compiler/world-compiler.mjs');await wait();abort();", "CORE_COMPILER"),
("  touchMod=await import('./input/studio-placement-touch-controller.mjs');await wait();abort();", "CORE_PLACEMENT_TOUCH"),
]
for old,name in steps:
    expr=old.strip()
    once(old, f"  __labStudioPhase(root,'{name}_START');\n  {expr}\n  __labStudioPhase(root,'{name}_DONE');")

once("    const serialMod=await import('./tools/register-core-tools-serial.mjs');\n    toolsMod={registerCoreTools:null,registerCoreToolsSerial:serialMod.registerCoreToolsSerial};",
     "    __labStudioPhase(root,'CORE_TOOL_BARREL_START');\n    const serialMod=await import('./tools/register-core-tools-serial.mjs');\n    __labStudioPhase(root,'CORE_TOOL_BARREL_DONE');\n    toolsMod={registerCoreTools:null,registerCoreToolsSerial:serialMod.registerCoreToolsSerial};")

once("  const core=await loadStudioCore(root,phoneBoot);",
     "  __labStudioPhase(root,'LOAD_STUDIO_CORE_START');\n  const core=await loadStudioCore(root,phoneBoot);\n  __labStudioPhase(root,'LOAD_STUDIO_CORE_DONE');")
once("  const adapter = createKeloRuntimeAdapter(root);",
     "  __labStudioPhase(root,'CREATE_ADAPTER_START');\n  const adapter = createKeloRuntimeAdapter(root);\n  __labStudioPhase(root,'CREATE_ADAPTER_DONE');")
once("  const initial = document || createWorldDocument({ worldId: mode === 'parcel' ? `parcel:${actorId || 'local'}` : 'world:kelo-main', metadata: { name: mode === 'parcel' ? 'My Parcel' : 'Kelo World', description: '', tags: [mode] }, settings: { tileSize: root.KELO_TILE_REGISTRY?.worldTileSize || 32, chunkSize: root.KELO_WORLD_RENDERER?.chunkSize || 512 } });",
     "  __labStudioPhase(root,'CREATE_DOCUMENT_START');\n  const initial = document || createWorldDocument({ worldId: mode === 'parcel' ? `parcel:${actorId || 'local'}` : 'world:kelo-main', metadata: { name: mode === 'parcel' ? 'My Parcel' : 'Kelo World', description: '', tags: [mode] }, settings: { tileSize: root.KELO_TILE_REGISTRY?.worldTileSize || 32, chunkSize: root.KELO_WORLD_RENDERER?.chunkSize || 512 } });\n  __labStudioPhase(root,'CREATE_DOCUMENT_DONE');")
once("  const kernel = createStudioKernel({ document: initial, adapter });",
     "  __labStudioPhase(root,'CREATE_KERNEL_START');\n  const kernel = createStudioKernel({ document: initial, adapter });\n  __labStudioPhase(root,'CREATE_KERNEL_DONE');")
once("  registerKeloComponents(kernel.components); seedCatalogPrefabs({ prefabRegistry: kernel.prefabs, assetCatalog: adapter.assetCatalog });",
     "  __labStudioPhase(root,'REGISTER_COMPONENTS_START');\n  registerKeloComponents(kernel.components);\n  __labStudioPhase(root,'REGISTER_COMPONENTS_DONE');\n  __labStudioPhase(root,'SEED_CATALOG_PREFABS_START');\n  seedCatalogPrefabs({ prefabRegistry: kernel.prefabs, assetCatalog: adapter.assetCatalog });\n  __labStudioPhase(root,'SEED_CATALOG_PREFABS_DONE');")
once("  const tools = phoneBoot && typeof registerCoreToolsSerial==='function'",
     "  __labStudioPhase(root,'REGISTER_CORE_TOOLS_START');\n  const tools = phoneBoot && typeof registerCoreToolsSerial==='function'")
once("    : registerCoreTools(kernel);",
     "    : registerCoreTools(kernel);\n  __labStudioPhase(root,'REGISTER_CORE_TOOLS_DONE');")

p.write_text(s)
