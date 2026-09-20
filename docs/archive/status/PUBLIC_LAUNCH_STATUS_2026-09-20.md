# Scrap-to-Bot Factory — Public Launch Status

Status date: **2026-09-20 UTC**  
Repository: **EverLeaf-Online/scrap-to-bot-factory**  
Baseline branch: **main**  
Baseline commit: **a5067bc** (`Fix paid-value durability, overclock recovery, and notification races (#86)`)

> **Roadmap note:** this file is the detailed launch-evidence snapshot. Current phase status and execution order live in `docs/ROADMAP.md`. Later commits may advance implementation without rewriting this evidence baseline.

## Release decision

**Do not switch the production experience to Public yet.**

The code-side launch hardening is substantially complete. PR #86 closed the three previously identified reliability findings: paid receipt acknowledgement now waits for durable ProfileStore confirmation, Server Overclock recovery retries after lease conflicts/transient failures, and FactoryReady delivery uses generation-aware claims to prevent stale duplicate sends. The remaining blockers are now concentrated in Roblox-platform/live-payment validation and real-device QA rather than missing core server authority.

## Automated launch gates completed

### Server authority and hostile-client coverage

The current automated/OCALE suite covers the valuable gameplay paths with server-owned state and hostile inputs:

- processor and assembler jobs use authoritative recipes, inputs, timing, and proximity;
- robot assignment/recycle validates ownership, work-slot limits, distance, contention, and duplicate recycle attempts;
- upgrade purchases validate IDs, exact server-side cost, proximity, max level, contention, and plot ownership;
- zone unlocks validate sequence, cost, robot requirements, owner gate, distance, repeat attempts, and visitor rejection;
- salvage collection validates plot ownership, unlocked zone, distance, storage capacity, transaction contention, single-winner node claims, and Auto-Collect entitlement;
- a read-only Factory visitor is exercised against processor, assembler, robot, upgrade, zone, and salvage mutation paths while the owner's profile remains unchanged;
- one-time Hub -> Factory route tokens now use an atomic MemoryStore claim tombstone, preventing two consumers from winning the same route-token race.

Relevant merged work: **#61, #64, #66, #68, #74, #75**.

### Monetization and paid-value correctness

Automated coverage now verifies the server behavior behind launch monetization:

- Production 2x entitlement;
- Expanded Storage;
- +2 Bot Work Slots;
- Auto-Collect;
- Factory VIP exact 15% assembler-time reduction at every configured assembler level;
- Factory Club storage multiplier and near-capacity boundary behavior;
- Instant Process Tokens for both processor and assembler jobs;
- personal-overclock stacking;
- Factory Club cosmetic ownership/equip persistence;
- developer-product receipt idempotency;
- bounded receipt history;
- failed paid grants do not consume receipt IDs;
- Starter Pack reward application is atomic and cannot partially grant.

Relevant merged work: **#62, #63, #69, #72**.

These tests verify authoritative game behavior after Roblox reports an entitlement/receipt. They do **not** replace a real charged Roblox purchase/subscription test.

### Persistence and reconnect integrity

Current-schema profile sanitization now covers malformed persisted economy values, jobs, robot assignments, entitlement flags, Factory Club cosmetics, receipts, and server-overclock lease IDs.

Valid active jobs, assignments, entitlements, route-independent progression, receipt IDs, and server-overclock lease state are explicitly verified to survive sanitization.

Relevant merged work: **#71**.

### Networking hardening

Public request remotes have:

- strict argument-count/type/length/range validation;
- per-player/per-action token-bucket rate limits;
- disconnect cleanup;
- centralized request/outbound remote catalogs;
- CI regression coverage requiring every public request remote to have a positive finite rate-limit policy and forbidding orphan rate-limit policies.

The reserved future `RequestPrestige` remote remains intentionally non-value-producing in the first public build.

Relevant merged work: **#79**.

### Performance baselines

Measured in Roblox Open Cloud/OCALE:

- max-inventory `TransactionRules.Snapshot`: approximately **0.635 ms/profile**;
- max-inventory committed transaction: approximately **0.584 ms/profile**;
- estimated sequential 8-player transaction tick at that baseline: approximately **4.7 ms**;
- full `StateService.BuildSnapshot + JSONEncode` at 500 robots: **0.200 ms/profile**;
- average max-profile full snapshot payload: approximately **15,950 bytes/profile**;
- estimated sequential 8-player full-snapshot burst: approximately **1.599 ms**;
- removing client-unused per-robot `AcquiredAt` reduced the measured 500-robot snapshot from **27,669 bytes to 15,669 bytes**, saving **12,000 bytes** in that regression fixture.

CI budgets now fail on major regression:

- Transaction snapshot/execute average: **<= 5 ms/profile**;
- full state snapshot build+encode average: **<= 2 ms/profile**;
- max-profile full snapshot payload average: **<= 20,000 bytes/profile**.

Relevant merged work: **#59, #73, #78**.

### Client/device code paths

Code-side device support now includes:

- reduced unnecessary client PathfindingService work;
- on-demand machine animation Heartbeat work;
- throttled objective direction projection;
- cleanup of presentation binding caches;
- phone-specific factory-panel row reflow;
- 44-pixel touch targets on the primary phone actions;
- phone-safe Factory Shop positioning/width and close control;
- gamepad focus ownership through `GuiService.SelectedObject`;
- gamepad-safe re-selection when UI controls disappear/disable;
- `ButtonB` back behavior for the main factory UI, Hub UI, and Factory Shop.

Relevant merged work: **#65, #76, #77**.

### Factory presentation

The public factory now uses the optimized approved industrial asset kit for substantially more of the environment, including optimized machine/support visuals, structural columns, sorted-material bins, and a walkable utility maintenance catwalk/stair section.

Imported visuals are forced anchored/non-colliding; gameplay collision remains server-authored through simple collision proxies.

Relevant merged work includes **#56, #60, #67, #70**.

## Remaining public-launch blockers

The following still require real Roblox/live-device validation before Public:

1. **Published reconnect smoke test**
   - leave/rejoin after active jobs and assignments;
   - verify profile/session release and reacquisition;
   - verify schema-v6/current-schema sanitization does not lose legitimate state.

2. **Real charged Developer Product matrix**
   - Material Supply Crate;
   - Instant Process Tokens;
   - personal Factory Overclock;
   - Starter Pack;
   - Server Overclock;
   - confirm the durable receipt ledger survives replay/rejoin behavior with actual Roblox receipt IDs.

3. **Server Overclock live recovery**
   - purchase on one live server;
   - interrupt/shut down/hop servers;
   - verify another server recovers only the remaining lease time and never extends the paid duration.

4. **Factory Club live subscription**
   - actual subscription ownership state;
   - subscriber effects;
   - monthly reward-cycle eligibility/idempotency;
   - cancellation/expiry behavior.

5. **Two-client live Factory visit**
   - owner + visitor route into the same reserved Factory;
   - confirm the visitor remains read-only under real Teleport/MemoryStore behavior;
   - repeat simultaneous route-consumption/server-hop attempts.

6. **Real-device QA**
   - small iPhone-class viewport;
   - small Android-class viewport;
   - tablet;
   - keyboard/mouse;
   - physical gamepad;
   - verify no clipped controls, unusable scrolling, focus traps, or inaccessible purchase/close actions.

7. **Low-end client profiling**
   - MicroProfiler/device stats on a representative low-end mobile device;
   - verify worker visuals, factory assets, machine effects, and UI together under realistic player load;
   - OCALE server CPU baselines above do not substitute for GPU/client-frame testing.

8. **Live delivery systems**
   - FactoryReady notification eligibility/delivery;
   - referral qualification/reward delivery;
   - Factory Club monthly reward condition;
   - NewContent/notification paths where applicable.

9. **Final published-build smoke**
   - fresh account first session;
   - returning account;
   - owner/visitor;
   - all monetization buttons;
   - first zone unlock;
   - bot assignment/recycle;
   - server hop/reconnect;
   - shutdown/rejoin;
   - no unexpected client/server errors.

10. **Repository protection**
    - verify `main` requires the intended CI/OCALE checks before merge.
    - the current GitHub App integration cannot read branch-protection configuration because it lacks repository administration permission, so this must be confirmed in GitHub settings.

## Public-launch gate

The release gate is now straightforward:

- all automated CI/OCALE checks green on `main`;
- no unresolved P0/P1 server-authority defect;
- all ten live/manual items above completed with evidence;
- final production-place smoke clean;
- only then switch audience to Public.

Automated tests should continue to be treated as regression guards after launch; real purchase, subscription, notification, teleport, and device behavior must remain on the release smoke matrix.
