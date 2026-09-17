from pathlib import Path

p=Path('src/creators/creator-entry.mjs')
s=p.read_text()

REMOVE_IMPORTS=[
"import { registerMapForgeWorkspace } from './workspaces/map-forge-workspace.mjs?v=map-forge-mobile-ui-20260916-1';\n",
"import { registerMountWorkspace } from './workspaces/mount-workspace.mjs';\n",
"import { registerAppearanceWorkspace } from './workspaces/appearance-workspace.mjs';\n",
"import { registerAnimationWorkspace } from './workspaces/animation-workspace.mjs';\n",
"import { registerVfxWorkspace } from './workspaces/vfx-workspace.mjs';\n",
"import { registerAbilityWorkspace } from './workspaces/ability-workspace.mjs';\n",
"import { registerSpriteAbilityWorkspace } from './workspaces/sprite-ability-workspace.mjs';\n",
"import { registerContentStudioWorkspace } from './workspaces/content-studio-workspace.mjs';\n",
"import { registerAssetSheetWorkspace } from './workspaces/asset-sheet-workspace.mjs';\n",
"import { registerAssetForgeWorkspace } from './workspaces/asset-forge-workspace.mjs';\n",
"import { registerAvatarWorkspace } from './workspaces/avatar-workspace.mjs';\n",
"import { registerDefinitionWorkspaces } from './workspaces/definition-workspaces.mjs';\n",
]
for row in REMOVE_IMPORTS:
    if row not in s:
        raise SystemExit(f'MISSING_IMPORT:{row.strip()}')
    s=s.replace(row,'',1)

old="registerWorldWorkspace(workspaces);registerMapForgeWorkspace(workspaces);registerMountWorkspace(workspaces);registerAppearanceWorkspace(workspaces);registerAnimationWorkspace(workspaces);registerVfxWorkspace(workspaces);registerAbilityWorkspace(workspaces);registerSpriteAbilityWorkspace(workspaces);registerContentStudioWorkspace(workspaces);registerAssetSheetWorkspace(workspaces);registerAssetForgeWorkspace(workspaces);registerAvatarWorkspace(workspaces);registerDefinitionWorkspaces(workspaces);"
if old not in s:
    raise SystemExit('MISSING_REGISTER_CHAIN')
s=s.replace(old,"registerWorldWorkspace(workspaces);",1)

# Mark the lab-only surgery so evidence cannot be mistaken for production code.
s=s.replace("let platform=null;","const __WORLD_ONLY_DIAGNOSTIC__=true;\nlet platform=null;",1)
p.write_text(s)
print('WORLD_ONLY_DIAGNOSTIC_APPLIED')
