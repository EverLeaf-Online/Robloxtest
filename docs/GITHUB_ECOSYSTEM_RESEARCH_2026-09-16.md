# Roblox GitHub Ecosystem Research — 2026-09-16

Purpose: turn the broad GitHub `roblox` repository search into a curated list of production-relevant sources for the new profit-first simulation game.

This document does **not** authorize copying arbitrary open-source games, scripts, assets, or exploit code. Every dependency must have clear provenance/license and must still fit current Roblox Creator Hub guidance.

## Source priority

1. Roblox Creator Hub and current official policy/API documentation.
2. `Roblox/creator-docs` — searchable public source synchronized from Roblox internal docs.
3. Official Luau sources.
4. Maintained Roblox OSS tooling/libraries with clear licenses and documentation.
5. Our own analytics/tests.
6. Community projects as optional references.
7. Exploit repositories only as defensive threat research.

## Strong sources / likely foundation

### Roblox/creator-docs

https://github.com/Roblox/creator-docs

Official public Creator documentation source. It was synchronized from Roblox internal docs on 2026-09-16, so this is a high-value searchable companion to `https://create.roblox.com/docs`.

Use for:
- API/platform behavior research;
- security guidance;
- monetization/policy research;
- analytics/discovery guidance;
- UI/performance/accessibility guidance;
- validating implementation assumptions before coding.

### luau-lang/luau

https://github.com/luau-lang/luau

Official Luau implementation/source.

Use for:
- language behavior;
- type-system behavior;
- performance/compiler details when Creator Hub docs are insufficient.

Do not write generic Lua 5.x code assumptions where Luau behavior differs.

### rojo-rbx/rojo

https://github.com/rojo-rbx/rojo

Active production filesystem/Studio synchronization tooling. Recent repository activity continued in July 2026.

Decision: **use** for the clean project workflow.

Benefits:
- source code in Git;
- VS Code/editor workflow;
- deterministic project structure;
- CI-friendly builds;
- easier reviews/diffs than Studio-only development.

### rojo-rbx/rokit

https://github.com/rojo-rbx/rokit

Next-generation Roblox toolchain manager. It is active, had 2026 updates, and explicitly supports existing Aftman/Foreman projects.

Decision: **use instead of Aftman**.

The previous Tiny Planet project's `aftman.toml` should not be restored as-is. `LPGhatguy/aftman` is archived.

### UpliftGames/wally

https://github.com/UpliftGames/wally

Roblox package manager with lockfile support.

Decision: **use where a third-party runtime/dev dependency is justified**.

Rules:
- keep runtime dependency count small;
- commit the lockfile;
- pin/review dependency versions before public release;
- do not add packages merely because they are popular.

### MadStudioRoblox/ProfileStore

https://github.com/MadStudioRoblox/ProfileStore

Player-data-oriented DataStore wrapper providing auto-save/session locking. The README explicitly targets preventing cross-server data conflicts and item duplication. Licensed Apache-2.0.

Decision: **preferred persistence baseline**, subject to a final code/security review before implementation.

Why it fits:
- session ownership/locking;
- player profile caching;
- autosave;
- designed around one profile per player;
- reduces risk of cross-server duplication compared with an ad-hoc data layer.

Still required around it:
- schema version/migrations;
- server-side sanitization and bounds;
- protected-mode behavior on load failure;
- idempotent purchase fulfillment;
- transaction design for any future trading.

ProfileStore does not replace economy validation or receipt idempotency.

### Roblox/jest-roblox

https://github.com/Roblox/jest-roblox

Current Roblox-maintained Jest port. The project states Roblox uses it for apps, core scripts, Studio plugins and libraries. Repository activity continued in September 2026. It supports Wally and Roblox/OCALE-based CI testing.

Decision: **preferred automated test framework**.

This replaces the instinct to use `Roblox/testez`, which is archived.

Priority test targets:
- economy math;
- progression requirements;
- price tables;
- reward calculations;
- profile migrations;
- receipt idempotency;
- rate limiter behavior;
- input validators;
- rarity tables and deterministic guaranteed-reward logic;
- offline-earnings caps;
- prestige/rebirth calculations.

### Roblox/roblox-lua-promise

https://github.com/Roblox/roblox-lua-promise

Roblox-maintained Promise implementation with 2026 activity and Wally distribution.

Decision: **optional**. Use when cancellable/composable async workflows materially improve clarity. Do not turn simple synchronous server logic into unnecessary Promise chains.

## Useful selective libraries

### Sleitnick/RbxUtil

https://github.com/Sleitnick/RbxUtil

Active utility collection with 2026 changes. Useful modules include Trove, Signal, TypedRemote, TaskQueue, Timer, Input and Component.

Decision: **select individual modules, not the whole library by default**.

Likely useful:
- `Trove` for deterministic cleanup;
- `Signal` where a custom signal abstraction is actually needed;
- `TypedRemote` or another typed networking layer if it improves auditability;
- `TaskQueue` if batching becomes necessary.

Avoid building the architecture around an unnecessary framework layer.

### dphfox/Fusion

https://github.com/dphfox/Fusion

Active reactive Luau library, MIT licensed, with 2026 activity.

Decision: **strong UI candidate**, but not locked until the first UI shell is prototyped.

Good fit for:
- shop panels;
- collection index;
- inventory/bot lists;
- animated progress bars;
- responsive HUD values;
- reactive upgrade state.

We should compare final implementation complexity against plain Roblox UI before locking it.

### jsdotlua/react-lua

https://github.com/jsdotlua/react-lua

Community-maintained React Lua fork derived from Roblox's React work.

Decision: **reference/alternative, not current default**.

It is a larger conceptual/runtime commitment than this simulator needs initially. Consider only if the UI grows complex enough to justify a React architecture.

### ffrostfall/ByteNet

https://github.com/ffrostfall/ByteNet

Typed buffer-based networking/serialization library.

Decision: **performance optimization candidate, not an initial dependency**.

The first simulator version does not need a specialized networking stack merely to send ordinary gameplay actions. Start with narrow, server-authoritative remote contracts and profiling. Consider ByteNet only if network bandwidth/serialization becomes a measured issue.

Important: serialization/type schemas do not replace gameplay authorization. A perfectly typed exploit request is still an exploit if the server fails to validate ownership/state/rate/proximity.

## Developer tooling candidates

### JohnnyMorganz/luau-lsp

https://github.com/JohnnyMorganz/luau-lsp

Use for editor language intelligence/type diagnostics where useful.

### JohnnyMorganz/StyLua

https://github.com/JohnnyMorganz/StyLua

Use for deterministic Luau formatting.

### Kampfkarren/selene

https://github.com/Kampfkarren/selene

Potential linting layer. Evaluate its current Roblox/Luau configuration at implementation time rather than adding it automatically.

## Official asset/research tooling worth knowing about

### Roblox/roblox-blender-plugin

https://github.com/Roblox/roblox-blender-plugin

Official Blender-related Roblox tooling. Relevant if the game moves into a repeatable Blender asset pipeline.

### Roblox/cube

https://github.com/Roblox/cube

Official Roblox 3D foundation-model research. Current repo includes Cube 3D/CubePart work, with a May 2026 CubePart update.

Decision: **asset R&D reference only**. It is not a runtime game dependency. Any generated assets still need optimization, licensing/provenance checks, visual QA and Roblox import validation.

## Repositories we should NOT choose as new foundations

### Sleitnick/Knit

https://github.com/Sleitnick/Knit

Archived and explicitly marked no longer maintained.

Decision: **do not build the new simulator around Knit**.

Its service/controller ideas are still understandable architectural history, but we can implement small explicit services without inheriting an archived framework.

### Roblox/testez

https://github.com/Roblox/testez

Archived.

Decision: use current `Roblox/jest-roblox` for new automated tests instead.

### LPGhatguy/aftman

https://github.com/LPGhatguy/aftman

Archived.

Decision: use Rokit for the new toolchain.

### Roblox/roact

https://github.com/Roblox/roact

Archived legacy UI library.

Decision: do not start new UI work on Roact. If we need a declarative UI framework, compare Fusion and current React Lua instead.

## Broad GitHub search warning

Searching `roblox` on GitHub returns a mixture of:
- production developer tooling;
- launchers/client utilities;
- exploit repositories;
- macros/autofarms;
- decompiled/ripped games;
- beginner tutorials;
- old archived libraries;
- current high-quality OSS.

Star count or search ranking is **not** a safety/quality/freshness signal by itself.

Before adopting any repository:
1. verify archive/maintenance status;
2. inspect recent commits/issues/releases;
3. inspect license;
4. read the actual source for sensitive code;
5. compare behavior against current Creator Hub docs;
6. minimize runtime dependencies;
7. pin versions/lockfiles;
8. threat-model any networking/economy abstraction;
9. do not reuse third-party game assets/code without compatible rights.

## Current proposed clean-project stack

At implementation start, the default stack should be:

- **Language:** Luau with strict typing where practical.
- **Source workflow:** Rojo.
- **Toolchain manager:** Rokit.
- **Package manager:** Wally.
- **Formatting:** StyLua.
- **Editor/type tooling:** Luau LSP.
- **Persistence:** ProfileStore + our schema/economy/receipt layer.
- **Tests:** Jest Roblox.
- **Architecture:** small explicit server services/client controllers; no monolithic framework.
- **Cleanup/signals:** selected RbxUtil modules only when useful.
- **UI:** prototype plain Roblox UI vs Fusion, then lock one.
- **Networking:** standard narrow remotes initially; ByteNet only after profiling demonstrates need.
- **Async:** Roblox Promise only where async composition/cancellation is useful.
- **Security:** server authoritative; exploit repositories remain test/threat references only.

## Profit-first engineering implication

The technical stack should reduce development and maintenance cost rather than become a project itself.

Every dependency must answer at least one business-relevant question:
- Does it reduce bugs/data loss?
- Does it speed iteration/content updates?
- Does it improve mobile UX/performance?
- Does it make monetization safer?
- Does it make analytics/experiments easier?
- Does it materially reduce exploit risk?

If the answer is no, we probably do not need it for v1.
