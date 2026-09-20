# Scrap-to-Bot Factory — Live Validation Status

Status date: **2026-09-17**  
Source branch after merge: `main`  
Normal Rojo project: `default.project.json`

> **Historical status:** this 2026-09-17 file is retained as validation evidence. Use `docs/ROADMAP.md` for current phase/priorities. The later 2026-09-20 evidence snapshot is archived beside this file as `PUBLIC_LAUNCH_STATUS_2026-09-20.md`.

This is the execution and validation record for the Scrap-to-Bot Factory first playable. It supersedes older 2026-09-16 runtime assumptions where they conflict.

## Published test experience

- Experience/universe ID: `10766713640`
- Test place used by OCALE: `75490500628229`
- Current test experience name: `Scrap-to-Bot Factory - Tests`
- Current access during validation: Private
- Dedicated Jest/OCALE project: `test.project.json`

## Configured Roblox products

### Passes

- Factory VIP: `1982714688`
- Auto-Collect: `1982138684`
- +2 Bot Work Slots: `1985060498`
- Expanded Storage: `1985786272`
- 2x Production: `1982138683`

### Developer Products

- Material Supply Crate: `3713191213`
- 15-Minute Factory Overclock: `3713191406`
- Instant Process Tokens: `3713191584`
- Starter Pack: `3713191832`
- Server Overclock: `3713191857`

### Subscription

- Factory Club: `EXP-418664834641560145`

### Experience notifications

- FactoryReady: `3e45ef59-0f23-ee44-9365-5c4402e5e3cd`
- ReferralReward: `806403da-e0cf-494e-9cb7-974fab0ff1a4`
- FactoryClubReward: `9de31ecb-88a8-4645-843a-b90c1952419d`
- NewContent: `e1abb235-8da6-814a-a388-a99aefb23213`

## Git / runtime reconciliation — complete

The full repository content audit is complete. Useful branch-only work was selectively ported into the canonical architecture and obsolete branch pointers were removed. The runtime source of truth is `main` + `default.project.json`.

The meaningful feature recovered from the old parallel implementation was bounded offline bot production. It was reimplemented against the current services rather than restoring the obsolete parallel filesystem/service layout.

## Core gameplay / persistence

Implemented at first-playable level:

- server-authoritative salvage collection;
- processor and assembler jobs;
- server-selected robot outcomes;
- robot ownership, assignment, unassignment, and recycling;
- passive and bounded offline production;
- machine, storage, and work-slot upgrades;
- zone progression;
- ProfileStore-backed persistence and session locking;
- profile migration/reconcile/sanitize flow;
- published reconnect persistence for Credits, materials, robots, assignments, upgrades, and zone progression.

Profile schema is now **v6**. Schema v6 adds the persisted Server Overclock lease identifier used for crash recovery.

## Paid entitlement correctness hardening

The post-audit paid-value fixes are merged into the canonical implementation:

- **+2 Bot Work Slots:** base work-slot progression is pass-independent and the entitlement is applied exactly once.
- **Factory VIP:** assembler duration uses fractional server timestamps and exact `0.85` duration multiplication, preserving the advertised 15% reduction at short upgraded durations.
- **Factory Club storage:** storage multipliers are passed explicitly into transaction drafts instead of depending on live table identity.
- **Developer Product receipts:** a durable receipt ledger supplements the bounded recent-receipt cache so old PurchaseIds remain protected after cache rotation.
- **Factory Club billing cycles:** reward grants defer when Roblox payment-history cycle resolution fails; no synthetic month fallback is created.
- **Game Pass completion:** ownership is re-checked through `UserOwnsGamePassAsync` before the entitlement is cached as owned.

Earlier Studio pass tests remain historical evidence. The hardened pass/subscription paths still need the manual regression matrix listed below before public launch.

## Server Overclock durability / server-hop semantics

Server Overclock is no longer treated as volatile per-server Lua state.

The current design uses `ServerOverclockCoordinator` plus durable DataStores:

- a purchase is protected by a lifetime PurchaseId marker;
- the active boost is represented by a cross-server lease;
- only the server holding the lease applies the server-wide production multiplier;
- lease duration is 75 seconds with a 30-second heartbeat;
- a second live server cannot claim the same unexpired lease;
- after a crashed owner lease expires, another server can recover the remaining boost without extending its expiry;
- clean shutdown releases the lease;
- the purchaser profile stores the lease ID and boost expiry for recovery discovery.

The lease/rule layer is covered by automated tests. A real charged-Robux purchase followed by a server interruption/server-hop is still required for live-platform validation.

## Client state ordering / replication

Implemented:

- stale full `StateSnapshot` payloads are rejected by revision;
- stale production deltas remain rejected;
- a delta arriving before the initial snapshot triggers a throttled resync request instead of being silently lost;
- machine countdowns use `Workspace:GetServerTimeNow()` and match fractional server timestamps;
- the clock-driven React update runs at 1 Hz rather than 4 Hz;
- bursty full snapshot sends are coalesced by `StateService`, while explicit resync requests bypass the coalescer;
- 1 Hz passive production continues to use the lightweight production delta rather than cloning/replicating the full robot inventory.

Further replacement of routine full snapshots with targeted deltas remains a performance optimization, not a correctness blocker.

## Maintainability cleanup

The post-audit cleanup is now implemented:

- `src/server/Data/ProfileTypes.lua` defines the strict durable `ProfileData` contract;
- DataService, EconomyService, StateService, ProductionService, ReferralService, BadgeService, MachineService, MonetizationService, RobotVisualService, and related helpers consume typed profile data at durable boundaries;
- remaining `any` values are intentionally limited to dynamic boundaries such as hostile RemoteEvent input, Roblox/DataStore API payloads, migration/sanitization of malformed persisted data, generic callback results, and React/wire payloads;
- `Settings.UI` uses `unknown` rather than an unrestricted durable-data `any` escape hatch;
- repeated character-position/proximity lookup is centralized in `src/server/Util/PlayerCharacter.lua` and shared by Machine, Robot, Salvage, Upgrade, and Zone services;
- the former monolithic React `App.lua` is split into the root component plus `Theme.lua`, `Components.lua`, `StateHelpers.lua`, and `PanelContent.lua` without moving economy/progression authority to the client.

## Automated validation

The dedicated OCALE test DataModel now runs two Jest groups.

Latest fully green PR #11 baseline:

- shared/domain suite: **9/9 suites, 55/55 tests**;
- server integration suite: **3/3 suites, 12/12 tests**;
- OCALE test-place version: **58**;
- Wally lock validation: passed;
- StyLua: passed;
- Selene: passed;
- shipping Rojo build: passed;
- test Rojo build: passed.

Current server integration coverage includes:

- EconomyService paid/storage capacity behavior inside isolated transaction drafts;
- profile schema v6 migration/sanitization for Server Overclock lease IDs;
- ServerOverclockLeaseRules purchase idempotency, exclusive ownership, stacking, expiry recovery, renewal, and release.

Coverage should still expand around full MonetizationService receipt orchestration, MachineService completion/reconnect behavior, RobotService contention, and hostile-client/multiplayer concurrency.

## Live persistence / engagement status

Previously verified in a published client:

- Credits, materials, owned robots, assignments, upgrades, and zone progression survive reconnect;
- notification opt-in controller runs and the test account shows the experience with notifications enabled.

Implemented but still requiring real published multi-server/billing conditions:

- NewContent cross-server delivery;
- ReferralReward delivery after real referral qualification;
- FactoryClubReward delivery for a real billing cycle;
- FactoryReady delivery after Roblox notification eligibility is sufficient for meaningful testing.

FactoryReady polling still depends on at least one active Roblox server. An always-on external/Open Cloud worker remains a later reliability option if zero-server delivery is required.

## Manual / live tests still pending before public launch

- rerun +2 Bot Work Slots and confirm one baseline slot becomes exactly three total;
- rerun Factory VIP at every configured assembler level and confirm exact 15% duration reduction;
- rerun Factory Club storage at near-capacity transaction boundaries;
- published reconnect smoke test after schema v6 migration;
- actual charged Developer Product receipt fulfillment;
- durable receipt-ledger behavior with a real Roblox receipt;
- personal-overclock persistence after a charged purchase;
- charged Server Overclock purchase followed by interruption/server-hop recovery;
- actual Factory Club subscription status and monthly reward cycle;
- hostile-client tests for distant/nonexistent salvage, assignment spoofing, duplicate sell, repeated upgrade, zone skip, malformed numbers, and forged purchase-like requests;
- two-player ownership/race/concurrency pass;
- mobile, small-screen, and gamepad QA;
- low-end client and 8-player/max-profile performance profiling;
- FactoryReady/ReferralReward/FactoryClubReward/NewContent live delivery conditions listed above.

## Current engineering TODO

The earlier `ProfileData`, duplicated `playerPosition`, and monolithic `App.lua` cleanup items are complete. Remaining engineering priorities are:

- expand server integration tests into MonetizationService, MachineService, RobotService, transaction contention, and reconnect paths;
- continue replacing large routine full snapshots with targeted state deltas where measurement justifies it;
- profile transaction deep-copy/sanitize cost with representative max robot inventories and eight players;
- finish gamepad focus/navigation, small-screen/mobile QA, and low-end performance work;
- implement stronger physical factory progression, robot reveal animation/VFX/audio, and production-quality world presentation;
- protect `main` with required CI checks/rules before broader collaboration.

## Launch interpretation

The repository is beyond architecture/graybox-only implementation and has meaningful automated server coverage, but it is **not public-launch validated yet**. Do not mark paid or platform-dependent paths as production-verified until the required real Robux, multi-server, notification-eligibility, and device tests have actually run.
