# Branch / Runtime Reconciliation — 2026-09-17

This document is the source of truth for how Git branches relate to the Roblox Studio/Rojo runtime for Scrap-to-Bot Factory.

## Authoritative runtime checkout

For normal Studio development and playtesting:

- Git checkout: `main`
- Rojo project: `default.project.json`
- `test.project.json` is only for the dedicated Jest/OCALE test project.

Rojo serves exactly one checked-out working tree. Git branches are not combined at runtime.

The repository previously used a stacked/layered development workflow. In that context, “layered” described branch ancestry and staged integration work, not multiple branches being mounted into Studio simultaneously.

## Why `main` is the complete current runtime

Commit `4727e7a5e11201538e3fedb4db47a5e2b8b46e5f` explicitly merged the Scrap-to-Bot integration into `main` and consolidated architecture, graybox gameplay, monetization, engagement, persistence, and validation work.

Subsequent hardening and audit work was then merged into `main`, whose current reconciled head at the time of this audit is `4222b3adb2f012f53234928b9a5eb734b227a3a6` (`Harden server authority and production runtime safety`).

## Branch reconciliation

### Canonical integrated branch

- `main` — authoritative current runtime and normal Rojo checkout.

### Historical feature branches already represented in `main`

- `feat/scrap-to-bot-architecture`
- `feat/scrap-to-bot-graybox-loop`
- `feat/scrap-to-bot-monetization-engagement`

These branches are development history, not additional runtime layers. Their intended work was consolidated into `main`.

### Merged hardening/audit branches

- `fix/scrap-to-bot-post-merge-hardening-2026-09-17`
- `audit/static-security-performance-2026-09-17`

These are retained branch pointers for merged work. Their changes are represented in the current integrated `main` state even where squash/merge ancestry makes a simple ahead/behind comparison appear divergent.

### Backup/checkpoint branches

- `backup/checkpoint-before-reconcile-files`
- `backup/graybox-before-monetization-reconcile-2026-09-17`
- `backup/main-before-reconcile-safety`

These are safety checkpoints. Do not use them as the normal Studio/Rojo source and do not delete them merely to reduce branch count.

### Parallel implementation backup

- `backup/main-parallel-implementation-2026-09-17`

This branch is a genuinely divergent, older parallel implementation. It uses a different filesystem/service layout (`src/ReplicatedStorage`, `src/ServerScriptService`, `src/StarterPlayer`) versus the canonical integrated layout on `main` (`src/shared`, `src/server`, `src/client`).

It is **not** a runtime layer that should be overlaid on `main`, and it should **not** be merged wholesale. Doing so would duplicate/reintroduce competing services, remotes, UI, and data architecture.

Useful ideas or features that remain unique to that backup should be selectively ported into the canonical architecture only after review. Current examples worth evaluating later include its explicit offline-production implementation and some gamepad/UI-navigation work. Those are feature-port candidates, not evidence that Studio should run from the backup branch.

## Development rule going forward

Normal development starts from current `main`, then uses a short-lived feature/fix branch when making changes. Studio/Rojo serves whichever branch is currently checked out in that working tree. After the feature branch is reviewed and merged, return the normal Studio checkout to `main`.

Do not describe feature branches as simultaneously “layered into” the running game. When discussing branch layering, state explicitly whether the meaning is Git ancestry/integration history or runtime state.

## Studio safety rule

Before switching the branch backing an active Rojo session:

1. confirm the Git working tree is clean or intentionally committed;
2. stop/disconnect the existing Rojo session if the switch changes a large part of the DataModel;
3. switch branches;
4. restart Rojo with the intended project file;
5. reconnect Studio and inspect the sync diff before accepting destructive changes.

For the current canonical game, the intended combination is `main` + `default.project.json`.
