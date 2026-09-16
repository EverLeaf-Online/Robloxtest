# Scrap-to-Bot Factory — First Playable Status

Status date: **2026-09-16**  
Branch: `feat/scrap-to-bot-graybox-loop`

This is the execution status for the first playable graybox. It separates implemented code plus static/build validation from Roblox runtime verification so we do not claim behavior that has not been executed, visually inspected, or interactively tested yet.

## Implemented; static/build checks green

The systems below are implemented in source. The complete code head immediately before this documentation refresh passed the current repository formatting, lint, dependency-lock, shipping-build, OCALE-runner-syntax, and test-project-build gates in **CI #113**. This documentation-only commit still requires its own CI run before the branch head is called green. Runtime behavior still belongs to the Studio/OCALE section below.

### World / multiplayer plots

- shared starter yard and salvage field;
- 8 generated personal factory plots;
- deterministic first-free plot allocation;
- plot owner labels and clean release on player leave/session release;
- players are explicitly removed with a clear message if no factory plot can be allocated instead of entering a broken no-plot session;
- requesting player's plot ID included in safe replicated state;
- local client highlights only the player's own factory and labels it `YOUR FACTORY`;
- processor/assembler prompt paths reject foreign-plot use;
- processor/assembler remote paths resolve only against the requesting player's allocated plot;
- each plot contains graybox material storage, recycle station, upgrade console, robot-index terminal, work pads, and reserved expansion sockets.

### Core loop

- authoritative salvage collection with distance, cooldown, storage, node existence, and zone validation;
- starter first-collect bonus;
- processor jobs with durable start/completion timestamps;
- assembler jobs with durable start/completion timestamps;
- cheaper first robot assembly recipe;
- server-selected robot outcome;
- 12 configured robot outcomes;
- Common / Uncommon / Rare / Epic rarity tiers;
- guaranteed usable first-reveal pool;
- robot assignment to server-validated unlocked work pads;
- assigned bots can be explicitly unassigned so a full lineup never becomes permanently locked;
- server-calculated passive Credit generation;
- idle robot recycling;
- server-priced processor, assembler, storage, and work-slot upgrades.

### Physical progression / presentation

- assigned robots are generated for their owner's unlocked work pads;
- locked work pads cannot retain/render stale robot visuals after load;
- robot graybox visuals use configured body, head, tool, locomotion, accent, rarity, and production metadata;
- player factories are placed together in one shared yard;
- visible Circuit Yard gate;
- isolated Circuit Yard salvage area;
- return portal to the starter yard;
- higher-yield Zone 2 salvage configuration;
- physical plot props reserve later art/asset replacement points without changing economy code.

### UI / collection

- responsive React HUD implementation;
- Credits and three launch materials;
- first-session objective guidance;
- machine job countdown/status;
- assigned factory plot number;
- Bots tab with assignment, unassignment, and recycling controls;
- Upgrades tab with authoritative prices/levels;
- Robot Index tab;
- collection completion count;
- undiscovered robot names remain masked;
- discovered robots show rarity, family, production rate, and currently owned count;
- Circuit Yard unlock progress shown after the first upgrade.

### Progression

- Circuit Yard initial graybox requirement: **2,500 Credits + 3 lifetime robots built**;
- zone requirements are data-driven;
- zone unlock is implemented as an atomic server transaction;
- gate travel requires the authoritative physical gate proximity check;
- locked-zone salvage performs server-side progression checks, including inside the transaction;
- current zone is persisted and sanitized.

### Persistence / security

- ProfileStore-backed profile lifecycle;
- Studio mock store path;
- schema migration/reconciliation/sanitization;
- atomic profile transaction wrapper;
- bounded economic values;
- durable machine jobs;
- saved work-pad assignments are normalized to owned robots, unique robot UIDs, valid pad IDs, and currently unlocked work slots;
- stale `Robots.NextUid` counters are repaired on profile load;
- assembler completion searches for a free robot UID before writing and never blindly overwrites an existing robot entry;
- robot UID allocation safely wraps at the configured integer ceiling;
- safe state snapshots omit server-only receipt/entitlement internals;
- server-owned prices, rewards, robot outcomes, production rates, upgrade targets, and zone costs;
- rate-limited action remotes, including the unassign action;
- proximity validation for physical actions;
- foreign-plot machine interaction rejection;
- duplicate robot sell prevention through authoritative ownership mutation;
- no trading in the first playable;
- no paid randomized robot rewards.

### Analytics

- onboarding funnel steps 1-10 implemented;
- first movement observed by server code;
- milestone events read only from server-confirmed profile state;
- batched passive-production Credit-source events;
- batched robot-recycle Credit-source events;
- immediate upgrade Credit sinks;
- immediate zone-unlock Credit sink;
- Studio analytics calls suppressed.

## Current GitHub CI gate

GitHub CI currently validates:

- Wally lockfile freshness;
- StyLua formatting;
- Selene lint;
- Bash and PowerShell OCALE runner syntax;
- shipping Rojo project build;
- Jest/OCALE test Rojo project build.

Jest spec files currently exist for:

- factory/economy rules;
- progression/zone rules;
- validation helpers;
- deterministic plot allocation;
- assignment normalization, including duplicate/invalid/locked-pad cleanup;
- collision-safe robot UID allocation, wraparound, malformed counters, and bounded exhaustion behavior.

The full accumulated code hardening head passed **CI #113** on 2026-09-16. The current documentation-only head is pending its own CI run.

**Important:** GitHub CI does not currently execute the Jest suite. It proves the test project and spec source build/lint cleanly, not that the specs passed in a Roblox runtime. Actual Jest execution is a Studio/OCALE runtime gate.

## Must be verified in Roblox Studio / OCALE

These are **not** considered complete until tested in an actual Roblox runtime:

- execute `spec.lua` and confirm the Jest suite is green;
- clean game boot with no runtime errors;
- fresh-player end-to-end loop: collect -> process -> assemble -> reveal -> assign -> earn -> upgrade;
- first robot appears correctly on Pad 1;
- assigned bot can be unassigned, replaced, and recycled after becoming idle;
- robot model pieces are aligned/oriented correctly for all locomotion/body variants;
- two players receive different plots;
- one player cannot use another player's processor or assembler through prompts;
- plot release/reassignment works after leave/rejoin;
- `YOUR FACTORY` local marker points to the correct plot for each player;
- plot stations do not overlap machines, pads, labels, or player movement paths;
- all ProximityPrompts are reachable and readable;
- Circuit Yard gate proximity, unlock, teleport, salvage, and return portal work physically;
- Zone 2 nodes remain unusable before unlock when reached by forced movement/teleport;
- HUD does not overlap Roblox movement controls on small mobile screens;
- Bots / Upgrades / Index tabs work with mouse and touch;
- scrolling lists behave correctly at small viewport sizes;
- reconnecting with an active processor/assembler job completes safely;
- profile save/load behavior is correct across a real reconnect;
- two-player server performance is stable with visible robot models;
- low/mid mobile frame rate is acceptable.

## OCALE readiness

The repository has a real Jest entrypoint in `spec.lua` and a `test.project.json`. An OCALE runner can execute them once this simulator has its own dedicated Roblox test universe/place and API key.

Required runtime environment values:

- `ROBLOX_API_KEY`;
- `ROBLOX_UNIVERSE_ID`;
- `ROBLOX_PLACE_ID`.

The API key must be scoped to the dedicated test place with the permissions required by Roblox Open Cloud Luau Execution. Do not commit the key or reuse universe/place IDs from another EverLeaf project.

## Intentionally blocked until the core-loop smoke test passes

Do not tune or ship these before the first playable has been validated in Studio:

- final pass prices;
- final developer-product prices;
- production pass/product IDs;
- player-facing shop purchase flow;
- final starter pack/value ladder;
- subscription offers;
- rewarded-video integration;
- price optimization / managed-pricing decisions;
- acquisition spend;
- large content expansion beyond the validated loop.

Existing monetization architecture/config hooks may remain in the codebase, but no IDs should be invented or reused from another EverLeaf project.

## Immediate next execution order

1. Keep the branch green in GitHub CI.
2. Continue static abuse/persistence auditing until the runtime test environment is available.
3. Configure a dedicated simulator test universe/place and scoped OCALE API key when available.
4. Execute the Jest suite in OCALE or Studio.
5. Sync/open the branch through the user's local Rojo/Roblox Studio workflow.
6. Run a fresh-player desktop smoke test.
7. Run a two-player ownership/plot smoke test.
8. Run a small-screen/mobile UI pass.
9. Fix every runtime/layout issue found and re-run CI/runtime tests.
10. Only then begin the first monetization UI/receipt slice.
