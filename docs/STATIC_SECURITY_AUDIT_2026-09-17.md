# Scrap-to-Bot Factory — Static Security & Performance Audit

Audit date: **2026-09-17**  
Audit branch: `audit/static-security-performance-2026-09-17`  
Pull request: **#5 — Audit server authority, production replication, and runtime safety**

This pass is intentionally code-first. Multiplayer, mobile-device, reconnect, and published-server smoke tests are deferred until the later runtime QA pass and are not treated as development failures.

## Scope reviewed

The audit covered the authoritative state, networking, persistence, monetization, engagement, progression, factory, robot, salvage, and presentation paths, including:

- `DataService`, `TransactionRules`, profile sanitization, ProfileStore session locking, save/release behavior;
- `RemoteService`, per-action rate limiting, request validation, and player cleanup;
- plot ownership, machine interaction, robot management, upgrades, zone unlocks, salvage claims, and bot production;
- Developer Product receipt processing, entitlement caches, Factory Club rewards, notification queues, badges, referral state, and admin broadcasts;
- player-keyed tables, long-running loops, event connection cleanup, bounded histories/caches, robot visual counts, and state replication cost.

## Security/correctness fixes in PR #5

### Robot control is now physically server-authoritative

`src/server/Services/RobotService.lua` now requires the requesting player to be within the configured server interaction distance of their own `BotConsole` before assigning, unassigning, or recycling robots.

The server still independently validates robot ownership, work-slot availability, assignment occupancy, and recycle eligibility. A client firing the remote directly cannot bypass the physical interaction requirement.

### Factory upgrades now require server-side proximity

`src/server/Services/UpgradeService.lua` now resolves the requesting player's own `UpgradeConsole` through `PlotService` and enforces the configured server interaction distance before spending credits or applying an upgrade.

### FactoryReady distributed locking is ownership-safe

`src/server/Services/FactoryReadyNotificationService.lua` now verifies the value returned from `UpdateAsync` before treating a lock as acquired. Lock release is also conditional on the current server still owning the lock.

This removes two race hazards from the previous implementation:

- an `UpdateAsync` callback retry could previously make a server believe it acquired a lock that another server ultimately owned;
- a blind lock removal could previously erase a lock newly acquired by another server.

### Badge award retries no longer get suppressed by a false Roblox result

`src/server/Services/BadgeService.lua` now treats `AwardBadgeAsync()` returning `false` as an unsuccessful award and clears the session attempt flag so the award can be retried.

### Receipt-history sanitization matches the live receipt processor

The profile sanitizer previously normalized receipt history to 100 entries while the receipt processor retained up to 500. `GameConfig.Economy.MaxReceiptHistory = 500` is now the shared sanitizer limit, preventing the sanitizer from silently discarding 400 receipt IDs after a load/transaction cycle.

The history is still intentionally bounded; it is not a lifetime external receipt ledger.

### Production credits survive transaction contention

`src/server/Services/ProductionService.lua` previously advanced the production tick/remainder before entering `DataService.Transaction`. A concurrent transaction could therefore return `TRANSACTION_BUSY` and cause that tick's earned credits to disappear.

Production now keeps a bounded server-side carry and restores attempted grants to that carry when the transaction cannot commit. The value is retried on a later production tick and cleared at the hard credit cap.

### Prestige remote has an explicit future rate policy

`RequestPrestige` already exists in the networking catalog even though no current prestige handler is bound. It now has a conservative rate-limit policy so a future handler cannot accidentally become an unthrottled request path.

## Performance changes

### Removed 1 Hz full-profile replication from bot production

Before this audit, each successful production tick called `StateService.PushSnapshot()`. A full snapshot clones and replicates the complete owned-robot dictionary, which is allowed to contain up to **500 robots**.

With the current maximum of eight factory plots/players, the old hot path could clone and serialize thousands of robot records per second even though a production tick usually changes only credits and one tutorial flag.

PR #5 adds `StateService.PushProductionDelta()`. Production now sends only:

- profile revision;
- current credits;
- lifetime credits;
- `FirstIncomeEarned` tutorial state.

The React client consumes these deltas and merges only the changed subtrees.

### +2 work-slot entitlement is represented in the bot UI

The server already allowed the +2 Bot Work Slots pass, but the bot UI's free-pad calculation used only the base machine work-slot count. The client now derives the two entitlement slots from the server-controlled player entitlement attribute and caps the result at the same configured maximum used by the server.

This is a presentation fix only; the server remains authoritative over actual assignment acceptance.

## Memory/leak review

No obvious unbounded player-session table growth was found in the audited services.

- `DataService` releases player profiles and transaction state.
- `RateLimiter` forgets player buckets on leave.
- plot ownership is released on profile release/player leave.
- monetization, analytics, badge, production, referral, visual, and entitlement-presentation player maps are cleaned when players leave.
- admin-broadcast dedupe is bounded to 100 IDs per server.
- receipt history is bounded to 500 IDs per profile.
- Factory Club cosmetics, referral rewards, owned robots, work pads, materials, and progression values are sanitized to configured caps.
- UI/event connections created by React effects and entitlement presentation are disconnected during cleanup/rebind.

## Instance / loop cost

The active robot presentation is bounded by work slots, not by total inventory. At current configuration a plot can visually deploy at most six assigned bots, so eight full plots produce at most **48 deployed robot visuals**, rather than 500 robots per player.

The recurring server loops are bounded by current players or fixed world content. The main remaining CPU item to profile later is the one-second production transaction: `DataService.Transaction` deep-copies and sanitizes the player's profile before committing. At a pathological eight-player server with 500 stored robots each, that can scan/copy roughly 4,000 robot records per production interval. This is acceptable for the current implementation target but should be measured with MicroProfiler during the later multiplayer/max-profile load pass before launch.

## Existing server-authoritative paths confirmed by code review

The following protections were already present and remain intact:

- remote requests require a loaded profile and pass through per-action token-bucket rate limits;
- request handlers are wrapped in `pcall` by `RemoteService`;
- processor and assembler requests resolve the requesting player's own plot machines and enforce server distance;
- physical machine prompts reject foreign-plot interaction;
- salvage validates node ID, active state, server position, unlocked zone, storage capacity, and a server node-claim lock;
- salvage rechecks progression inside the profile transaction;
- zone travel/unlock resolves the authoritative server gate, checks server distance, and evaluates progression/currency server-side;
- robot ownership, assignment state, and recycle rewards are read from the requesting player's server profile;
- upgrade costs and machine levels are computed server-side;
- Developer Product fulfillment runs through the server receipt path, records receipt IDs before successful acknowledgement, and saves successful grants before returning `PurchaseGranted`;
- creator broadcasts are server-authorized, filtered, rate-limited, and bounded in size/cache.

## Validation completed for this audit branch

GitHub CI passed on the final audit branch, including:

- Wally install and lockfile validation;
- StyLua formatting check;
- Selene lint;
- OCALE runner-script validation;
- shipping Rojo build;
- test Rojo build.

The OCALE runtime workflow also passed on the audit branch. The dedicated test place published as version **47**, and the Jest suite completed through Roblox Open Cloud Luau Execution with **8/8 suites and 49/49 tests passing**.

## Known product/durability items intentionally not changed

These require a product/architecture decision rather than a silent code change:

- **Server Overclock** remains server-session state. A server shutdown does not restore the remaining paid server timer in a replacement server, and there is a small receipt-save-to-memory-side-effect crash window.
- **Starter Pack** remains a Developer Product. The shop hides it after first claim, but if Roblox allows a later charged repeat purchase the server must fulfill the receipt and currently grants the pack again. If the product must be truly one-time, the product model should be changed rather than denying an already charged receipt.
- receipt deduplication remains a bounded 500-entry profile history. Lifetime receipt deduplication would require a durable external/per-purchase ledger design.
- FactoryReady remains dependent on an active game server polling its ordered queue. An always-on external worker would be needed for guaranteed due-time processing while the experience has zero active servers.

## Runtime verification deferred by request

Come back to these after the code-first development/audit work:

- two-player unique plot assignment and foreign-plot interaction rejection;
- simultaneous salvage-node race behavior;
- crafted remote requests from beyond the 14-stud interaction envelope;
- forced movement into a locked zone followed by salvage/gate attempts;
- leave/rejoin while processor or assembler jobs are active, verifying exactly-once completion;
- two factories operating simultaneously while profiling CPU, instance count, network traffic, and robot replication;
- mobile HUD/touch and small-screen behavior;
- actual charged Developer Product purchase and personal-overclock persistence;
- real Factory Club subscription refresh/reward;
- FactoryReady notification delivery after the experience reaches the platform eligibility threshold;
- ReferralReward, FactoryClubReward, and cross-server NewContent live delivery.

These are **runtime verification pending**, not failed checks.

## Follow-up watch item

`StateDelta` rejects revisions older than the current client snapshot. Full `StateSnapshot` messages still replace client state directly. If later profiling/testing exposes cross-remote delivery reordering between `StateSnapshot` and `StateDelta`, add the same revision guard to full-snapshot acceptance. This is currently a defensive follow-up item, not an observed failure.
