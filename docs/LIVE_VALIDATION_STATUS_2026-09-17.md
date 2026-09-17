# Scrap-to-Bot Factory — Live Validation Status

Status date: **2026-09-17**  
Source branch: `main`  
Current runtime hardening head before this documentation update: `27a724751a3a833a74e3532c784da979f3383ea8`

This is the current authoritative execution status for the first-playable, monetization, persistence, engagement, and audit-hardening passes. It supersedes older runtime assumptions in `FIRST_PLAYABLE_STATUS_2026-09-16.md` where they conflict.

## Published test experience

- Experience/universe ID: `10766713640`
- Current published test experience name: `Scrap-to-Bot Factory - Tests`
- Current access during validation: Private
- Rojo/Git source branch: `main`
- Normal Rojo project: `default.project.json`

## Creator products configured

### Passes

- Factory VIP: `1982714688`
- Auto-Collect: `1982138684`
- +2 Bot Work Slots: `1985060498`
- Expanded Storage: `1985786272`
- 2x Production: `1982138683`

### Developer products

- Material Supply Crate: `3713191213`
- 15-Minute Factory Overclock: `3713191406`
- Instant Process Tokens: `3713191584`
- Starter Pack: `3713191832`
- Server Overclock: `3713191857`

### Subscription

- Factory Club: `EXP-418664834641560145`

### Notifications

- FactoryReady: `3e45ef59-0f23-ee44-9365-5c4402e5e3cd`
- ReferralReward: `806403da-e0cf-494e-9cb7-974fab0ff1a4`
- FactoryClubReward: `9de31ecb-88a8-4645-843a-b90c1952419d`
- NewContent: `e1abb235-8da6-814a-a388-a99aefb23213`

## Git / branch reconciliation — complete

The full repository branch-content audit was completed and useful branch-only work was selectively ported into the canonical architecture. The obsolete feature, audit, checkpoint, and parallel-implementation branches were then removed from the remote. `main` is the runtime source of truth.

The important parallel-branch feature that was missing from the canonical implementation — bounded offline production — was reimplemented against the current services rather than restoring the obsolete parallel architecture.

## Core gameplay / persistence — verified

Implemented and validated at first-playable level:

- server-authoritative salvage collection;
- processor jobs;
- assembler jobs and server-selected robot outcomes;
- robot ownership, assignment, unassignment, and recycling;
- passive production;
- machine/storage/work-slot upgrades;
- zone progression;
- bounded offline production;
- ProfileStore-backed persistence and session locking;
- profile migrations and sanitization;
- published reconnect persistence for Credits, materials, robots, assignments, upgrades, and zone progression.

The first-playable is still a graybox/early presentation build. Physical factory transformation, reveal polish, gamepad/mobile QA, broader service integration tests, and launch-scale performance validation remain later work.

## Studio monetization validation — historical tests plus hardened implementation

The following behaviors were previously verified in Roblox Studio using the dedicated Studio test harness and Roblox Marketplace test-purchase prompts where applicable:

- 2x Production grants the expected exact production multiplier;
- Expanded Storage entitlement applies;
- Auto-Collect entitlement applies;
- +2 Bot Work Slots allows three total work slots from the one-slot baseline;
- Factory VIP nameplate presentation works;
- Instant Process Tokens can be consumed against valid jobs;
- Factory Club Studio activation uses the live entitlement/state path;
- Factory Club monthly test bundle grants materials and tokens;
- Factory Club collectible cosmetic ownership/equip presentation works;
- live shop Developer Product/subscription prompts resolve configured products and dynamic prices.

A later static audit found correctness defects in three paid-benefit implementation details even though the earlier Studio checks appeared successful. Those code defects are now fixed on `main`:

- **+2 Bot Work Slots:** the shared work-slot rule is now pure; the client pass bonus is applied exactly once instead of being counted in both `FactoryRules` and the React HUD.
- **Factory VIP assembler speed:** assembler jobs now use fractional server timestamps and exact duration multiplication, so the configured `0.85` multiplier remains a true 15% duration reduction even on short upgraded jobs.
- **Factory Club storage:** storage entitlement multipliers are now passed explicitly into economy transactions instead of being attached to the live profile table identity, so transaction drafts retain the correct capacity.

These three benefits should be run once more through the Studio monetization matrix after the hardened build is synced/published. Until that rerun, treat the old visual/manual result as historical validation and the new implementation as CI/OCALE-validated code, not as a fresh manual runtime result.

## Receipt processing / paid-value hardening

Developer Products remain server authoritative through `MarketplaceService.ProcessReceipt`.

Current implementation guarantees/behavior:

- product IDs and grant amounts are resolved server-side;
- failed grants return `NotProcessedYet`;
- successful profile grants are saved before `PurchaseGranted`;
- the bounded recent-receipt list remains as a fast profile-local replay cache;
- a separate durable receipt ledger now protects old PurchaseIds after they rotate out of that bounded cache;
- live receipt-ledger DataStore failures fail closed and return `NotProcessedYet`;
- Studio receipt replay continues to use the mock/profile path without production DataStore writes;
- paid material grants can exceed ordinary storage capacity but never the absolute profile material cap;
- personal overclock repeat purchases extend rather than reset remaining time;
- Server Overclock purchase expiry is now written into durable purchaser profile state before acknowledgement and can be re-adopted after a later profile load;
- Game Pass purchase completion is re-verified with `UserOwnsGamePassAsync` before caching ownership as true.

The prior Studio receipt replay test remains valid for the recent-receipt path:

- `ReplayLastReceipt: PASS (RECEIPT_REPLAY_IDEMPOTENT)`

Still requiring a real paid published-session test:

- actually charged Developer Product receipt fulfillment;
- durable receipt-ledger behavior under a real Roblox receipt;
- personal overclock persistence after a charged purchase;
- Server Overclock recovery behavior after a charged purchase and server loss/rejoin.

## Factory Club billing-cycle hardening

The subscription status and monthly reward paths were hardened after the static audit.

Previous behavior used a calendar-month fallback when Roblox payment-history lookup could not resolve the actual billing cycle. A later successful payment-history request could therefore produce a different cycle ID for the same paid cycle.

Current behavior:

- subscription status can still enable Factory Club perks when Roblox confirms the subscription;
- monthly material/token/cosmetic rewards are granted only when an authoritative payment-history cycle start can be resolved;
- payment-history failure no longer invents a fallback cycle ID;
- an unresolved cycle leaves the reward pending instead of risking a duplicate grant;
- the last granted authoritative cycle remains persisted in the profile.

A real subscribed account is still required to production-validate this path.

## Client state-ordering hardening

The React client state path was hardened after the audit:

- stale `StateSnapshot` payloads are rejected by revision instead of unconditionally replacing newer client state;
- the latest accepted snapshot is held in a ref for remote-callback ordering checks;
- if a production delta arrives before the initial full snapshot, the client requests a fresh state snapshot instead of silently dropping the ordering gap;
- resync requests are throttled to at most once per second;
- existing stale-delta revision rejection remains;
- machine countdown presentation uses `Workspace:GetServerTimeNow()` so it matches fractional server machine timestamps;
- the clock-driven React update was reduced from 4 Hz to 1 Hz.

CI, lint/build validation, OCALE runtime execution, and CodeQL passed for this hardening PR.

## Live persistence/reconnect — verified

Verified in the published Roblox client before the newest hardening changes:

- Credits persist across leave/rejoin;
- materials persist across leave/rejoin;
- owned robots persist across leave/rejoin;
- robot work-pad assignments persist across leave/rejoin;
- upgrades persist across leave/rejoin;
- zone progression persists across leave/rejoin;
- general saved progression restores correctly through a real published-session reconnect.

The profile schema is now version 5 because durable Server Overclock recovery state was added. Existing profiles migrate forward through the normal migration/reconcile/sanitize path. A fresh published reconnect smoke test after syncing the hardened build is still recommended.

## Notification opt-in — verified live

The published Roblox client executed the opt-in controller and logged:

- `WAITING_FOR_DELAY`
- `CHECKING_ELIGIBILITY`
- `PROMPT_UNAVAILABLE`

Roblox account settings were inspected and confirmed:

- the test experience appears under **My Games — Games with enabled notifications**;
- its notification toggle is enabled;
- Roblox game-event desktop/mobile notification settings are enabled for the account.

`PROMPT_UNAVAILABLE` is not treated as an error because Roblox does not expose a more specific reason when `CanPromptOptInAsync()` returns false.

## Engagement hardening — implemented

Implemented on `main`:

- duplicate badge-award noise is avoided by checking ownership before award attempts;
- `FactoryClubRewardGranted` is wired to the configured FactoryClubReward notification;
- `RequestAdminBroadcast` has a server-authoritative creator check;
- creator-entered NewContent text is normalized, bounded, and filtered;
- NewContent announcements publish through `MessagingService` for active servers;
- active players receive the in-game announcement path;
- broadcast deduplication is bounded per server;
- referral reward announcements render through the existing client announcement path.

NewContent delivery is still **not marked live-verified** until a real cross-server published-session test is run.

## FactoryReady notification delivery — blocked for now

Implementation status:

- FactoryReady scheduling exists;
- durable queue/lock stores exist;
- server-side Open Cloud notification sender is wired;
- official Open Cloud `UserNotification` package source is vendored under Git/Rojo control;
- client opt-in state is confirmed enabled.

Live delivery is **not yet marked verified**.

Current blocker for meaningful production delivery validation: Roblox experience-notification eligibility requires the experience to reach the platform visit threshold before personalized delivery can be relied on for testing. Re-test FactoryReady after the experience reaches **100 visits**.

Production delay is restored to:

- `FactoryReadyDelaySeconds = 30 * 60`

Architecture limitation still tracked: the FactoryReady queue is polled by active Roblox game servers. If no game server is alive when a queued notification becomes due, nothing currently processes it until a game server is active again. An always-on Open Cloud worker is a later reliability option.

## Automated validation status

The project currently has nine shared/domain Jest suites, including offline-production coverage. The latest entitlement and client-state hardening changes passed the repository's automated gates:

- Wally lock validation;
- StyLua;
- Selene;
- shipping Rojo build;
- test Rojo build;
- OCALE no-publish Luau execution probe;
- OCALE Jest runtime execution;
- CodeQL with no new alerts in the changed code.

These tests do **not** replace the still-needed server-service integration and live multiplayer/device passes. The largest remaining automated-test gap is integration coverage for DataService/MonetizationService/MachineService/EconomyService/RobotService interactions and hostile-client concurrency cases.

## Live tests still pending

Pending because they require a hardened-build Studio/published rerun, Robux, platform eligibility, or a real multi-server test:

- rerun +2 Bot Work Slots against the hardened client calculation;
- rerun Factory VIP duration and confirm exact 15% duration reduction at all configured assembler levels;
- rerun Factory Club storage against near-capacity transaction scenarios;
- published reconnect smoke test after profile schema v5 migration;
- actual charged Developer Product purchase in the published experience;
- durable receipt-ledger confirmation with a real Roblox receipt;
- actual Factory Club subscription state/monthly reward in production;
- personal-overclock live persistence after a real purchase;
- Server Overclock recovery after a charged purchase and server interruption/rejoin;
- FactoryReady push delivery after the experience reaches 100 visits;
- ReferralReward push delivery under real referral qualification;
- FactoryClubReward push delivery under a real subscription billing cycle;
- NewContent cross-server announcement/notification delivery validation;
- hostile-client/multiplayer runtime test pass;
- mobile/small-screen/gamepad QA;
- low-end and max-profile performance profiling.

## Current known engineering TODO

High-priority work remaining after the paid-entitlement fixes:

- add server-service integration tests for receipt, economy/storage, subscription, machine, robot, transaction-contention, and migration paths;
- replace routine full-profile client snapshots with targeted deltas where practical;
- profile full-profile transaction copy/sanitize cost under max inventory and multiplayer load;
- introduce a typed `ProfileData` contract to reduce `any` across the durable data path;
- split the large React `App.lua` surface into testable components/hooks as the UI grows;
- complete gamepad navigation, small-screen/mobile QA, and low-end performance profiling;
- implement stronger physical factory progression and robot reveal polish before public validation;
- protect `main` with required CI checks/rules before broader collaboration.

## Current completion state

### Verified enough to continue development

- core gameplay loop at first-playable level;
- base save/load/reconnect path;
- offline production implementation;
- server-authoritative economy/action validation;
- Studio Developer Product grant/replay path;
- Studio/live-shop prompt wiring;
- Factory Club Studio grant/presentation path;
- live notification opt-in controller path;
- full repository branch reconciliation;
- paid-entitlement correctness fixes merged and automated gates green;
- client state ordering fixes merged and automated gates green.

### Must still be runtime-validated before public launch

- hardened paid-pass/subscription edge cases listed above;
- real charged Robux receipts/subscription;
- hostile-client and multiplayer concurrency;
- mobile/gamepad/small-screen behavior;
- representative low-end/max-profile performance;
- notification delivery paths that depend on Roblox eligibility or real billing events.

Do not mark blocked live-platform items as failed merely because they currently require Robux, notification eligibility, or multi-server conditions.