# Branch / Runtime Reconciliation — 2026-09-17

This document is the source of truth for how Git branches relate to the Roblox Studio/Rojo runtime for Scrap-to-Bot Factory.

## Authoritative runtime checkout

For normal Studio development and playtesting:

- Git checkout: `main`
- Rojo project: `default.project.json`
- `test.project.json` is only for the dedicated Jest/OCALE test project.

Rojo serves exactly one checked-out working tree. Git branches are not combined at runtime.

The repository previously used stacked feature branches. In that context, “layered” described Git ancestry and staged integration work, not multiple branches being mounted into Studio simultaneously.

## Full content audit result

The earlier branch-role review was followed by a full branch-by-branch content audit in `docs/FULL_GIT_CONTENT_AUDIT_2026-09-17.md` and PR #7.

That audit inspected the surviving content of every branch, including the divergent `backup/main-parallel-implementation-2026-09-17` tree. The parallel implementation was intentionally not merged wholesale because it used an obsolete competing service/filesystem architecture. Its one meaningful missing gameplay feature, bounded offline production, was reimplemented against the canonical architecture and merged into `main`; useful operational documentation was also reconciled. Obsolete duplicate services and incomplete controller/HUD code were explicitly rejected or deferred with reasons.

The legacy feature, audit, backup, reconciliation, and parallel-implementation refs covered by that audit were subsequently removed from the remote. Their history remains preserved by Git commits and merged pull requests.

## Current rule

`main` is the complete active game runtime. A non-main branch is only a temporary development branch for work not yet merged.

When a short-lived branch is merged, its branch pointer may remain briefly as Git history housekeeping, but it is not another runtime layer and does not need to be overlaid into Studio. Once its work is verified in `main`, the branch can be deleted.

Current hardening work after the full audit has continued through normal short-lived PRs, including paid-entitlement fixes, client revision ordering, live-validation documentation, and server-integration/Server Overclock lease hardening. Those merged changes are part of `main`.

## Development rule going forward

1. Start from current `main`.
2. Create a short-lived feature/fix branch when needed.
3. Rojo serves that branch only because it is the checked-out working tree.
4. Review, test, and merge the branch into `main`.
5. Return the normal Studio checkout to `main`.
6. Delete the merged branch after confirming it has no unique required content.

Do not describe feature branches as simultaneously “layered into” the running game.

## Studio safety rule

Before switching the branch backing an active Rojo session:

1. confirm the Git working tree is clean or intentionally committed;
2. stop/disconnect the existing Rojo session if the switch changes a large part of the DataModel;
3. switch branches;
4. restart Rojo with the intended project file;
5. reconnect Studio and inspect the sync diff before accepting destructive changes.

For the canonical game, the intended combination is always `main` + `default.project.json` unless intentionally testing a short-lived development branch.
