# Scrap-to-Bot Factory — First Playable Status

Status date: **2026-09-16**  
Branch: `feat/scrap-to-bot-graybox-loop`

This is the execution status for the first playable graybox. It separates implemented code plus static/build validation from Roblox runtime verification so we do not claim behavior that has not been executed, visually inspected, or interactively tested yet.

## Implemented; static/build checks green

The complete accumulated first-playable code head passed the repository formatting, lint, dependency-lock, shipping-build, OCALE-runner-syntax, and test-project-build gates in **CI #159**. The first documentation refresh then passed the same branch gate in **CI #160**. Runtime behavior still belongs to the Studio/OCALE section below.

### World / multiplayer plots

- shared starter yard and salvage field;
- 8 generated personal factory plots;
- deterministic first-free plot allocation;
- plot owner labels and clean release on player leave/session release;
- players are explicitly removed with a clear message if no factory plot can be allocated instead of entering a broken no-plot session;
- profile release cleanup is emitted exactly once so plot/session consumers can reliably clear per-player state;
- requesting player's plot ID included in safe replicated state;
- local client highlights only the player's own factory and labels it `YOUR FACTORY`;
- processor/assembler prompt paths reject foreign-plot use;
- processor/assembler remote paths resolve only against the requesting player's allocated plot;
- ProximityPrompt activation distance is config-driven at 12 studs;
- server interaction checks use a 14-stud envelope, leaving only 2 studs of latency/position slack instead of the previous 20/24-stud crafted-remote advantage;
- each plot contains graybox material storage, recycle station, upgrade console, robot-index terminal, work pads, and reserved expansion sockets.

### Core loop

- authoritative salvage collection with distance, cooldown, storage, node existence, and zone validation;
- a shared salvage node is synchronously claim-locked before profile mutation so two players cannot receive the same node reward concurrently;
- failed salvage transactions release only the invisible node claim instead of flickering/disabling the shared prompt for other players;
- starter first-collect bonus;
- processor jobs with durable start/completion timestamps;
- active processor output reserves material-storage space, preventing later salvage from consuming the slot needed for completion;
- bounded recovery support completes processor jobs that were already stalled by pre-reservation profile state;
- assembler jobs with durable start/completion timestamps;
- cheaper first robot assembly recipe;
- server-selected robot outcome;
- 12 configured robot outcomes;
- Common / Uncommon / Rare / Epic rarity tiers;
- guaranteed usable first-reveal pool;
- robot assignment to server-validated unlocked work pads;
- assigned bots can be explicitly unassigned so a full lineup never becomes permanently locked;
- assignment requests reject already-assigned robots and occupied pads instead of silently moving/replacing lineup state;
- server-calculated passive Credit generation;
- fractional passive Credits survive temporary idle/unassign periods instead of being discarded;
- passive-production work is skipped while the player is already at the configured Credit cap;
- idle robot recycling;
- destructive robot recycling requires the full configured Credit payout to fit, so a bot cannot be destroyed for a truncated payout near the Credit cap;
- server-priced processor, assembler, storage, and work-slot upgrades.

### Runtime-cost hardening

- machine polling still checks timing at 0.25-second cadence, but it no longer enters the profile transaction/deep-copy boundary unless a processor or assembler job is actually due;
- this removes approximately 64 unnecessary profile drafts per second in an 8-player idle server under the previous implementation;
- passive production skips its assignment scan, profile transaction, analytics path, and full state push while Credits are capped;
- robot visual synchronization remains bounded to four work pads per player;
- full state snapshot/delta-protocol optimization remains a runtime-profiling decision rather than an unmeasured rewrite.

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
- persisted zone progression is normalized through the contiguous configured zone catalog, so malformed/high saved values cannot pre-unlock future zones;
- saved machine upgrade levels normalize against the actual configured upgrade-level arrays instead of hard-coded `1..4` limits;
- high legacy upgrade levels clamp to the highest configured level instead of resetting a player to level 1 when content definitions change.

### Persistence / security

- ProfileStore-backed profile lifecycle;
- Studio mock store path;
- schema migration/reconciliation/sanitization;
- profile preparation is fail-closed: session start is protected, original profile data is snapshotted before migration/reconcile/sanitize, preparation failure restores the original state before ending the session, and the player is not admitted with uncertain data;
- `Profile:IsActive()` is enforced for readiness, data access, transaction start, pre-commit, and load registration;
- profile transactions execute against a deep draft and replace live contents only after a successful commit preparation;
- failed, declined, throwing, or sanitize-failing transactions do not leak partial mutations into live profile data;
- per-player transaction serialization rejects re-entrant/concurrent transactions;
- a transaction cannot commit after its ProfileStore session has moved/ended;
- bounded economic values;
- durable machine jobs;
- unknown persisted material keys are removed so invisible garbage cannot permanently consume material capacity;
- saved work-pad assignments are normalized to owned robots, unique robot UIDs, valid pad IDs, and currently unlocked work slots;
- robot ownership keys must use canonical bounded `R<number>` UIDs;
- stale `Robots.NextUid` counters are repaired on profile load;
- assembler completion searches for a free robot UID before writing and never blindly overwrites an existing robot entry;
- robot UID allocation safely wraps at the configured integer ceiling;
- tutorial milestones use a known-key allowlist so unknown persisted entries cannot grow replicated state;
- receipt history is normalized into a dense ordered list, malformed/arbitrary keys are removed, duplicate purchase IDs collapse to their newest occurrence, IDs are length-bounded, and only the newest 100 entries survive;
- safe state snapshots omit server-only receipt/entitlement internals;
- cached entitlement flags remain non-authoritative and are not used by the current graybox economy;
- server-owned prices, rewards, robot outcomes, production rates, upgrade targets, and zone costs;
- rate-limited action remotes, including the unassign action;
- proximity validation for physical actions;
- foreign-plot machine interaction rejection;
- duplicate robot sell prevention through authoritative ownership mutation;
- no trading in the first playable;
- no paid randomized robot rewards;
- the reserved prestige remote has no bound value-producing service in the first playable.

### Analytics

- onboarding funnel steps 1-10 implemented;
- first movement observed by server code;
- milestone events read only from server-confirmed profile state;
- batched passive-production Credit-source events;
- batched robot-recycle Credit-source events;
- immediate upgrade Credit sinks;
- immediate zone-unlock Credit sink;
- analytics calls occur after profile commits, not inside the serialized transaction boundary;
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

- factory/economy rules, including processor storage reservation and data-driven upgrade-level normalization;
- progression/zone rules, including persisted-zone normalization;
- validation helpers;
- deterministic plot allocation;
- assignment normalization, including duplicate/invalid/locked-pad cleanup;
- canonical/collision-safe robot UID parsing/allocation, wraparound, malformed counters, and bounded exhaustion behavior;
- transaction rollback, thrown callbacks, prepare-commit failure, successful draft commit, and snapshot/restore isolation;
- receipt-history normalization, duplicate handling, sparse/arbitrary keys, malformed IDs, and bounded history.

Latest verification:

- complete accumulated gameplay/security/runtime-cost code head: **CI #159 green**;
- first refreshed status-document head: **CI #160 green**.

**Important:** GitHub CI does not currently execute the Jest suite. It proves the test project and spec source build/lint cleanly, not that the specs passed in a Roblox runtime. Actual Jest execution is a Studio/OCALE runtime gate.

## Must be verified in Roblox Studio / OCALE

These are **not** considered complete until tested in an actual Roblox runtime:

- execute `spec.lua` and confirm the Jest suite is green;
- clean game boot with no runtime errors;
- fresh-player end-to-end loop: collect -> process -> assemble -> reveal -> assign -> earn -> upgrade;
- first robot appears correctly on Pad 1;
- assigned bot can be unassigned, replaced, and recycled after becoming idle;
- salvage respects reserved processor output capacity while a job is running;
- completed processor output does not stall after the player continues salvaging;
- constructed legacy/stalled processor state recovers without creating repeatable over-cap material value;
- two players racing the same salvage node produce only one successful collection;
- a failed/full-storage salvage attempt does not visibly flicker or disable the node for other players;
- crafted machine/gate/salvage remotes outside the 14-stud server envelope are rejected;
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
- reconnecting with an active processor/assembler job completes safely and only once;
- profile save/load behavior is correct across a real reconnect and session handoff;
- two-player server performance is stable with visible robot models;
- machine polling and passive-production profiling confirms acceptable server CPU/network cost;
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
2. Continue static abuse/persistence/runtime-cost auditing until the runtime test environment is available.
3. Configure a dedicated simulator test universe/place and scoped OCALE API key when available.
4. Execute the Jest suite in OCALE or Studio.
5. Sync/open the branch through the user's local Rojo/Roblox Studio workflow.
6. Run a fresh-player desktop smoke test.
7. Run a two-player ownership/salvage-race/foreign-plot smoke test.
8. Run crafted-remote distance and locked-zone abuse checks.
9. Run a small-screen/mobile UI pass.
10. Fix every runtime/layout issue found and re-run CI/runtime tests.
11. Only then begin the first monetization UI/receipt slice.
