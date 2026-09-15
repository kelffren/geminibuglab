# Gemini Bug Lab — Mandatory Agent Workflow

This repository is the isolated experimentation environment for Kelo World.

## Absolute repository boundaries

- Production repository: `kelffren/gemini`.
- Laboratory repository: `kelffren/geminibuglab`.
- Do **not** modify `kelffren/gemini` while performing experiments in this lab.
- Do **not** force-push, delete production branches, alter production Pages, or automatically sync lab changes back to production.
- Historical backup/reference branches are immutable unless the user explicitly orders otherwise.

## Standard working method from now on

All risky development, debugging, refactors, experiments, migrations, and bug surgery follow this sequence:

1. **Freeze the source snapshot.** Record the exact production SHA used as the starting point.
2. **Keep lab `main` as the clean laboratory baseline.** Do not use it as a scratchpad for destructive experiments once a usable baseline exists.
3. **Create a dedicated experimental branch** for the task, for example `world-surgery`, `bug-0003-lab`, or `experiment/<name>`.
4. **Make all experimental code changes only on that branch.** Never test risky work directly in production.
5. **Every branch that changes visible behavior or interaction MUST be previewable through GitHub Pages from `kelffren/geminibuglab`.** A task is not ready for user validation until it has a phone-accessible lab preview.
6. **Lab Pages must be isolated from production Pages.** Never repoint, reuse, edit, disable, or otherwise modify the Pages deployment/configuration of `kelffren/gemini` to preview lab work.
7. **The preview must deploy only laboratory code.** Its source branch/workflow/deployment target must belong to `kelffren/geminibuglab`; it must not write into, publish from, or depend on changing the production repository.
8. **Label the preview clearly** with repository, source branch, build/SHA, and `LAB / NOT PRODUCTION` so it cannot be confused with the live game.
9. **Test on the preview from iPhone/Safari whenever behavior is mobile-sensitive.** Headless or mobile emulation is supporting evidence, not the final gate.
10. **Record evidence and result classification** using only: `HEADLESS PASS`, `MOBILE EMULATION PASS`, `REAL IPHONE PASS`, `REAL IPHONE FAIL`, or `UNKNOWN`.
11. **Do not declare a bug fixed from headless evidence alone.** Real iPhone/Safari validation is the final gate for iPhone freezes and rendering/input failures.
12. **If an experiment fails, keep production untouched.** Revert or abandon only the experimental branch and preserve evidence.
13. **When an experiment succeeds, isolate the smallest proven patch.** Do not copy the entire lab branch into production.
14. **Promotion to `kelffren/gemini` is a separate operation.** It requires explicit user instruction and must transfer only the tested patch after confirming the current production HEAD has not changed incompatibly.

## Pages preview contract — mandatory

The user works from iPhone, so previewability is part of the definition of done for visual, UI, input, rendering, World Editor, gameplay, or interaction work.

For those changes, agents MUST provide a mobile-accessible preview from the laboratory repository before asking the user to validate the work.

Allowed model:

```text
kelffren/gemini
  Production code
  Production Pages
  DO NOT TOUCH for lab preview

kelffren/geminibuglab
  main — clean lab baseline
  world-surgery / experiment/* — experimental source
  lab Pages deployment — preview only
```

Hard rules:

- `kelffren/gemini` Pages and `kelffren/geminibuglab` Pages are separate products and separate deployment targets.
- A lab preview must never overwrite or repoint the production Pages site.
- A lab workflow must never push preview output into `kelffren/gemini`.
- Never change production Pages settings merely to make an experimental branch visible.
- Prefer a dedicated lab deployment workflow or lab publish branch when needed.
- The preview should identify its source branch and SHA on-screen or in an easily visible diagnostics panel.
- If Pages preview is unavailable, classify the visual/mobile result as `UNKNOWN`; do not substitute production deployment as a shortcut.

## Debugging methodology

For difficult bugs, prefer isolation over broad rewrites:

- Instrument first.
- Split systems into controllable modules.
- Add feature flags / kill switches instead of deleting code.
- Disable modules progressively or with binary search.
- Record the last module started and last module completed.
- Identify the smallest reproducible failing boundary.
- Fix only that boundary.
- Re-enable systems incrementally and retest.

Use explicit evidence labels in reports:

- `[CONFIRMADO]` — directly demonstrated by code, logs, tests, or observed device behavior.
- `[INTERPRETACIÓN]` — strong conclusion from confirmed evidence.
- `[HIPÓTESIS]` — plausible but not proven.
- `[DESCONOCIDO]` — not yet tested or insufficient evidence.

## Concurrent-agent rule

Before every write:

- Re-read the latest target branch HEAD.
- Check for changes made by other agents.
- Do not overwrite unrelated work.
- Prefer small, reviewable commits with one purpose.

## World Editor historical anchors

Known historical GOOD boundary:
`ea14e48426ac20aff44da009f0d615d8562cf7cd`

First boot/mount regression found by bisect:
`c13cceafecd4edc9144a99a108eb2851f88a7541` — `studio: make paint copies interactive`

Later historical mitigation:
`51bd0453876296e1548b70e38f89338bfdb05f9a` — `fix(studio): stop Paint Copies DOM mutation storm`

These are diagnostic references, not permission to roll production back automatically.

## Core principle

**Experiment in `geminibuglab`, make the experiment previewable through lab Pages, keep production and production Pages untouched, prove it on the target device, then promote only the smallest verified patch.**
