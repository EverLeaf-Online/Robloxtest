# Scrap-to-Bot Factory — Roadmap

Status date: **2026-09-20 UTC**  
Repository: **EverLeaf-Online/scrap-to-bot-factory**  
Runtime source of truth: **`main` + `default.project.json`**

## Roadmap authority

This file is the **single current execution roadmap** for Scrap-to-Bot Factory.

Use the supporting documents for detail, not for competing phase status:

- `docs/ROADMAP.md` — current priorities, phase status, launch gates, and post-launch order.
- `docs/MASTER_PRODUCTION_PLAN.md` — product/design/architecture specification and long-term blueprint.
- `docs/INSTANCED_FACTORY_ARCHITECTURE.md` — current Hub + reserved personal Factory architecture.
- `docs/FACTORY_ASSET_PIPELINE.md` — active tool-agnostic visual-asset production/import specification.
- `docs/archive/` — historical status snapshots and retired workflows; evidence only.
- dated audit/research documents — historical/reference evidence unless this roadmap explicitly links them as an active gate.

When phase status changes, update **this file first**.

---

## Current state

### Product stage

**Closed / Limited Beta candidate: READY**

The project is beyond alpha/graybox. The complete server-authoritative core loop is implemented:

`collect -> process -> assemble -> reveal -> assign -> produce -> recycle/sell -> upgrade -> unlock zones`

The current build also includes:

- ProfileStore-style session-locked persistence and schema migration/sanitization;
- Hub -> reserved personal Factory routing with one-time MemoryStore route claims;
- owner/visitor authority separation;
- robot ownership, assignment, work slots, passive production, and bounded offline production;
- machine/storage/work-slot upgrades and zone progression;
- passes, Developer Products, Factory Club, receipts, paid-value durability, and overclock systems;
- strict public-remote validation and per-action rate limiting;
- analytics instrumentation and OCALE regression/performance coverage;
- experience notifications, referrals, badges, and engagement systems;
- Discord bot commands, reporting/feedback channels, Creator Hub webhook ingestion, private `#bot-ops` routing, and Roblox-server -> Discord announcement infrastructure;
- code-side phone/gamepad support and performance budgets;
- approved industrial factory asset pipeline and anchored/collision-safe imported visuals.

### Release classification

| Stage | Status | Gate |
| --- | --- | --- |
| Alpha / architecture | **Complete** | Core systems and server authority proven |
| First playable | **Complete** | Full gameplay loop playable |
| Closed / Limited Beta | **Ready** | Invite/limited players can be used for real-world QA and balance |
| Open / Public Beta | **Blocked on validation** | Complete the live-platform/device gate below |
| Full release / 1.0 | **Not yet** | Public-beta evidence, polish, packaging, and no unresolved P0/P1 issues |
| Post-launch expansion | **Planned** | Prestige, goals/orders, deeper social/live-ops systems |

---

# Phase 0 — Foundation and first playable

**Status: COMPLETE**

Completed work:

- Rojo/Rokit/Wally/Selene/StyLua toolchain;
- typed shared configs and request policies;
- persistence, migration, sanitization, reconnect support;
- server service architecture;
- salvage, processor, assembler, robot reveal/ownership/assignment/recycle;
- production and offline-production rules;
- upgrade and zone progression;
- Hub + Factory instancing architecture;
- mobile-aware core UI and gamepad navigation code paths;
- analytics and economy/progression funnels;
- monetization products/passes/subscription hooks;
- durable receipt handling and replay protection;
- Factory/Server Overclock durability;
- notification/referral/Factory Club engagement paths;
- hostile-client and contention coverage;
- automated OCALE/Jest/CI performance and correctness gates;
- production Discord bot and webhook infrastructure;
- optimized industrial environment assets.

No return to graybox architecture is planned unless beta data exposes a fundamental product problem.

---

# Phase 1 — Closed / Limited Beta

**Status: READY / ACTIVE NEXT**

Goal: put the current game in front of controlled real players and use the results to find device, balance, comprehension, retention, and live-platform defects before opening discovery traffic.

## Required beta operating setup

- [x] Core loop implemented.
- [x] Persistence and session locking implemented.
- [x] Server-authoritative economy and inventory.
- [x] Valuable remotes validated and rate-limited.
- [x] Monetization products and entitlement handling implemented.
- [x] Receipt idempotency/durability implemented.
- [x] Hub/Factory routing implemented.
- [x] Visitor mutation restrictions implemented.
- [x] Discord reporting/feedback/status infrastructure.
- [x] Roblox Creator Hub webhook -> VM -> `#bot-ops`.
- [x] Roblox Secret Store entry for the game -> Discord webhook credential.
- [x] Server-side Discord webhook sender implemented.
- [x] Automated CI/OCALE baseline green.
- [ ] Publish/sync the latest `main` build to the beta place.
- [ ] Fire one real Creator Admin announcement and verify exactly one post reaches `#announcements`.
- [ ] Run a fresh-account and returning-account beta smoke on the latest published build.

## Beta data to collect

During Limited Beta, prioritize:

- first-session completion;
- first scrap -> first process -> first bot -> first assignment timings;
- first upgrade and first zone-unlock conversion;
- session length;
- D1 return once enough players exist;
- economy source/sink balance;
- purchase prompt exposure and conversion;
- device/UI failure reports;
- player confusion points;
- client/server error rate;
- low-end performance observations.

Do not delay Limited Beta for prestige, daily goals, or post-launch social features.

---

# Phase 2 — Public Beta gate

**Status: IN PROGRESS**

The code-side launch hardening is substantially complete. Public Beta is blocked primarily by **real Roblox/live-device validation**, not by missing core server architecture.

Complete all of the following before changing the experience to unrestricted Public:

## 2.1 Published reconnect smoke

- [ ] Leave/rejoin with active jobs and robot assignments.
- [ ] Verify profile/session release and reacquisition.
- [ ] Verify current-schema sanitization preserves legitimate state.
- [ ] Verify shutdown/rejoin behavior on the current published build.

## 2.2 Real charged Developer Product matrix

Test with actual Roblox receipts:

- [ ] Material Supply Crate.
- [ ] Instant Process Tokens.
- [ ] Personal Factory Overclock.
- [ ] Starter Pack.
- [ ] Server Overclock.
- [ ] Verify durable receipt history survives replay/rejoin with real PurchaseIds.
- [ ] Verify failed grants are never acknowledged as consumed.

## 2.3 Server Overclock live recovery

- [ ] Buy on one live server.
- [ ] Interrupt/shut down/server-hop.
- [ ] Verify another server recovers only remaining paid duration.
- [ ] Verify no lease duplication or paid-time extension.

## 2.4 Factory Club live subscription

- [ ] Real subscription ownership state.
- [ ] Subscriber storage/cosmetic/utility effects.
- [ ] Monthly reward eligibility.
- [ ] Monthly reward idempotency.
- [ ] Cancellation/expiry behavior.

## 2.5 Two-client live Factory visit

- [ ] Owner + visitor enter the same reserved Factory.
- [ ] Visitor remains read-only under real Teleport/MemoryStore behavior.
- [ ] Simultaneous route-consumption attempts do not duplicate access.
- [ ] Server-hop/retry behavior remains correct.

## 2.6 Real-device QA

- [ ] Small iPhone-class device/viewport.
- [ ] Small Android-class device/viewport.
- [ ] Tablet.
- [ ] Keyboard/mouse.
- [ ] Physical gamepad.
- [ ] No clipped controls.
- [ ] No unusable scrolling.
- [ ] No gamepad focus traps.
- [ ] Purchase and close actions remain reachable.

## 2.7 Low-end client profiling

- [ ] MicroProfiler/device stats on representative low-end mobile hardware.
- [ ] Profile robot workers + factory assets + machine effects + UI together.
- [ ] Check frame pacing, memory, GPU load, and replication under realistic load.
- [ ] Fix any launch-blocking client hot path.

## 2.8 Live delivery systems

- [ ] FactoryReady eligibility/delivery.
- [ ] Referral qualification/reward delivery.
- [ ] Factory Club monthly reward condition.
- [ ] NewContent notification path.
- [x] Creator Hub platform webhook test.
- [x] Private Discord `#bot-ops` delivery.
- [ ] Published Roblox server -> Discord `#announcements` smoke.

Note: Roblox Analytics alert rules cannot be meaningfully configured until the experience reaches Roblox's required traffic threshold. The receiver/parser is already implemented and tested.

## 2.9 Final published-build smoke

- [ ] Fresh account.
- [ ] Returning account.
- [ ] Owner/visitor.
- [ ] All monetization buttons.
- [ ] First process/assemble/reveal.
- [ ] First bot assignment/recycle.
- [ ] First upgrade.
- [ ] First zone unlock.
- [ ] Server hop/reconnect.
- [ ] Shutdown/rejoin.
- [ ] Clean client/server logs.

## 2.10 Repository protection

- [ ] Confirm `main` protection/ruleset.
- [ ] Require intended CI checks before merge.
- [ ] Keep OCALE available as the Roblox runtime regression gate.

### Public Beta release rule

Public Beta may open only when:

- CI/OCALE are green on the release commit;
- no unresolved P0/P1 server-authority or paid-value defect exists;
- the live/manual matrix above has evidence;
- the current production-place smoke is clean.

---

# Phase 3 — Beta polish and retention

**Status: PARTIALLY IMPLEMENTED / CONTINUES DURING BETA**

These items improve retention and presentation. They should be driven by beta observations rather than blocking controlled testing.

## 3.1 Factory presentation

- [x] Industrial asset kit integrated.
- [x] Imported gameplay visuals forced anchored/non-colliding.
- [x] Server-authored collision proxies.
- [x] Structural columns, bins, catwalk/stair content.
- [ ] Stronger visible factory transformation as upgrades progress.
- [ ] Better visual differentiation between machine tiers.
- [ ] Final environment dressing/signage/lighting pass.
- [ ] Replace remaining weak/graybox-looking presentation.

## 3.2 Robot reveal quality

- [x] Authoritative robot outcome/reveal state.
- [ ] Production-quality reveal animation.
- [ ] Reveal VFX.
- [ ] Reveal audio.
- [ ] Stronger rarity readability.
- [ ] Better collection-gap feedback.

## 3.3 UX and onboarding

- [x] Core objective guidance.
- [x] Phone reflow and touch-target work.
- [x] Gamepad focus/back-navigation architecture.
- [ ] Tune FTUE from observed beta drop-off.
- [ ] Remove any unnecessary friction before first bot assignment.
- [ ] Balance first-session upgrade/zone pacing from real cohorts.

## 3.4 Networking/performance refinement

- [x] Performance regression budgets in CI/OCALE.
- [x] Lightweight production deltas.
- [x] Snapshot payload reduction work.
- [ ] Replace additional routine full snapshots with targeted deltas where measurement justifies it.
- [ ] Continue low-end visual/instance-count optimization from device profiles.

This is optimization, not a reason to redesign working server authority.

---

# Phase 4 — 1.0 release

**Status: FUTURE GATE**

1.0 should follow Public Beta rather than precede it.

Release criteria:

- Public Beta has enough real sessions to identify major retention/comprehension problems.
- No unresolved P0/P1 economy, persistence, receipt, routing, or authority defects.
- Real-device matrix is clean.
- Paid product/subscription behavior is proven live.
- Core loop pacing is stable enough that balance changes are incremental rather than structural.
- Factory presentation is strong enough for store thumbnails/trailer footage.
- Store metadata and screenshots accurately reflect real gameplay.
- Support/reporting/ops paths are functioning.
- Release build passes final reconnect/server-hop/shutdown smoke.

---

# Phase 5 — Post-launch progression expansion

**Status: PLANNED / NOT REQUIRED FOR BETA**

## 5.1 Prestige / factory tiers

Prestige is the largest intentionally unimplemented progression system.

Current groundwork already exists:

- `RequestPrestige` networking entry;
- rate-limit policy;
- `FactoryTier` profile field;
- `PrestigeCount` profile field;
- replicated progression state.

Still required:

- [ ] Prestige eligibility rules.
- [ ] Server-authoritative reset/retention transaction.
- [ ] Permanent bonus model.
- [ ] Factory-tier content unlocks.
- [ ] Prestige UI/confirmation.
- [ ] Analytics.
- [ ] Migration/sanitization tests.
- [ ] Replay/contention/exploit tests.

Do not bind the reserved remote until the full transaction semantics are defined and tested.

## 5.2 Daily/weekly goals and rotating orders

- [ ] Goal/order definitions.
- [ ] Server-owned progress.
- [ ] Daily/weekly reset semantics.
- [ ] Claim idempotency.
- [ ] Reward balancing.
- [ ] UI.
- [ ] Analytics.
- [ ] LiveOps configuration path.

## 5.3 Deeper social/co-op

Candidates after the base loop proves retention:

- [ ] Cooperative rush orders.
- [ ] Friend production bonus with a bounded cap.
- [ ] Collection showcase.
- [ ] Base/factory likes.
- [ ] Server event goals.
- [ ] Robot races/challenges.

Still excluded unless deliberately reconsidered:

- player trading;
- irreversible stealing;
- destructive griefing.

---

# Phase 6 — LiveOps and monetization scale

**Status: FUTURE / METRIC-GATED**

Only add these after sufficient traffic/data:

- new robot families and variants;
- new salvage zones/materials;
- new machine tiers;
- event configurations;
- rotating orders/goals;
- cosmetic collections;
- additional utility bundles;
- rewarded video after eligibility;
- regional/managed pricing;
- Roblox price optimization only when transaction volume makes the experiment meaningful;
- acquisition experiments after retention is acceptable.

Do not scale paid acquisition into a weak retention loop.

---

# Explicit non-blockers for Limited Beta

The following are **not required** before inviting beta players:

- Prestige.
- Daily/weekly goals.
- Rotating orders.
- Cooperative rush orders.
- Base likes.
- Collection showcases.
- Rewarded video.
- Regional pricing.
- Price optimization.
- Every planned VFX/audio polish item.
- An always-on external worker for FactoryReady when zero Roblox servers exist.

---

# Known architecture follow-ups

These are engineering improvements, not current core-loop omissions:

- targeted state deltas for additional high-frequency state changes;
- optional always-on/Open Cloud notification worker if zero-server delivery becomes a product requirement;
- additional full-service integration tests around real platform-dependent paths;
- continued content/config modularization as LiveOps volume grows.

---

# Working order from here

Unless a P0/P1 defect interrupts the sequence:

1. **Publish/sync current `main` to the beta place.**
2. **Run the Roblox -> Discord `#announcements` production smoke.**
3. **Run fresh/returning account smoke.**
4. **Start Closed/Limited Beta.**
5. **Collect device/comprehension/balance data.**
6. **Complete real purchase/subscription/server-hop/visitor validation.**
7. **Complete real-device and low-end profiling.**
8. **Fix beta findings and finish presentation polish.**
9. **Open Public Beta.**
10. **Use Public Beta data to tune retention/monetization.**
11. **Move to 1.0 when the public-beta gate is stable.**
12. **Build Prestige, goals/orders, social systems, and deeper LiveOps in metric-driven order.**

---

# Roadmap maintenance rule

To keep the repository organized:

- this file owns **current phase/status/priorities**;
- `MASTER_PRODUCTION_PLAN.md` owns **product and architecture specification**;
- dated `*_STATUS_YYYY-MM-DD.md` files are **evidence snapshots**, not competing roadmaps;
- research documents remain references and should not be treated as current implementation state;
- completed short-term TODOs should be removed from active sections rather than duplicated indefinitely;
- new large features must be placed into a roadmap phase before implementation unless they are emergency fixes.

The goal is one obvious answer to: **What is done, what is next, and what is intentionally later?**
