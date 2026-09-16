# Official Roblox Creator Hub Baseline

Research date: **2026-09-16**

Primary authority for this project: **https://create.roblox.com/docs**

This document converts Roblox's current official guidance into project rules. Third-party articles, competitor observations, Reddit, YouTube, and exploit repositories may inform research, but when they conflict with Roblox documentation, platform policy, or current API behavior, the official Creator Hub wins.

## 1. Product design rules

Roblox's game-design guidance separates a core loop into:

1. minute-to-minute interaction;
2. the most repeated action set;
3. the progression engine.

For this project, every prototype must identify all three before implementation begins.

Official references:
- https://create.roblox.com/docs/production/game-design
- https://create.roblox.com/docs/production/game-design/core-loops
- https://create.roblox.com/docs/production/game-design/design-for-roblox

### FTUE / onboarding

Roblox emphasizes getting players into the fun quickly because users can leave and switch games with little friction. Long text-heavy tutorials should be avoided. The first session should demonstrate progression, starter value, goals, and moments of joy quickly.

Project rule:
- first meaningful interaction immediately or within seconds;
- first visible reward very early;
- early thresholds intentionally low enough to demonstrate progression;
- teach the core loop through interaction and world/UI cues, not a tutorial wall;
- always expose a short-, medium-, and long-term goal;
- end onboarding with a satisfying reward/reveal/transformation.

Official reference:
- https://create.roblox.com/docs/production/game-design/onboarding

## 2. Discovery and retention rules

Roblox's current Recommended For You system prioritizes:

Most important:
- play-through rate;
- first-play bounce rate;
- play days per user;
- playtime per user.

Also important:
- intentional co-play days;
- qualified play sessions;
- spend days;
- Robux spent per user.

Project rule:
- never improve monetization at the cost of severe retention/bounce damage;
- packaging must accurately communicate the gameplay;
- social play must be a gameplay benefit, not a menu-only feature;
- design for multiple return days rather than a single-session completion curve.

Official reference:
- https://create.roblox.com/docs/discovery

## 3. Analytics-first implementation

Roblox provides economy, funnel, and custom AnalyticsService event types.

Project rule: analytics instrumentation is part of the MVP architecture, not a post-launch add-on.

### Initial funnels

Onboarding funnel:
1. Join
2. FirstMovementOrInput
3. FirstScrap
4. FirstProcess
5. FirstBotReveal
6. FirstBotAssigned
7. FirstIncomeClaim
8. FirstUpgrade
9. FirstZoneGoalSeen
10. FirstZoneUnlock

Monetization funnel:
1. ShopOpened
2. ProductViewed
3. PurchasePrompted
4. PurchaseReceiptGranted

Progression funnel:
1. FirstUpgrade
2. FirstAutomation
3. SecondProductionLine
4. FirstRareBot
5. FirstPrestigeEligible
6. FirstPrestige

### Economy tracking

Track at minimum:
- soft-currency sources;
- soft-currency sinks;
- premium/paid-related grants separately;
- material sources and sinks where they meaningfully affect balance.

### Custom events

Use a small stable event vocabulary and custom fields instead of creating a separate event name for every item/robot/zone.

Roblox currently allows up to 100 custom event names and three custom fields per event. Analytics events are server-sent and published-game only.

Official references:
- https://create.roblox.com/docs/production/analytics
- https://create.roblox.com/docs/production/analytics/event-types
- https://create.roblox.com/docs/production/analytics/custom-events
- https://create.roblox.com/docs/production/analytics/custom-fields

## 4. Validation order

Roblox's analytics guidance recommends improving retention/engagement/monetization before aggressively scaling acquisition.

Project order:
1. D1 retention and first-session engagement;
2. average session time;
3. D7/D30 return behavior;
4. payer conversion and ARPPU;
5. acquisition scaling;
6. monitor all of the above after every major update.

Do not invent universal target numbers. Use Creator Analytics similar-experience benchmarks when the game qualifies.

Official references:
- https://create.roblox.com/docs/production/analytics
- https://create.roblox.com/docs/production/analytics/analytics-dashboard

## 5. Monetization architecture

Supported monetization surfaces include:
- passes;
- developer products;
- subscriptions;
- private servers;
- paid access;
- Creator Rewards;
- Roblox Shop surfaces;
- managed/optimized pricing;
- advertising/rewarded advertising where eligible.

Project launch priority:
1. passes for permanent convenience/capacity;
2. developer products for repeatable guaranteed value and temporary acceleration;
3. Creator Rewards as passive upside from genuine engagement;
4. subscription only after repeat-session value is proven;
5. rewarded ads only when eligible and when rewards fit naturally;
6. managed pricing/price optimization only after enough transaction data exists.

Roblox currently states that price-optimization tests generally need around 60,000 transactions in the previous 30 days to produce useful recommendations, so this is not an early-launch dependency.

Official references:
- https://create.roblox.com/docs/production/monetization
- https://create.roblox.com/docs/monetize-experiences
- https://create.roblox.com/docs/production/monetization/developer-products
- https://create.roblox.com/docs/production/monetization/shop
- https://create.roblox.com/docs/production/monetization/price-optimization
- https://create.roblox.com/docs/creator-rewards

## 6. Developer product receipt rules

Developer products are repeatable purchases and must be granted from authoritative receipt processing.

Project rule:
- `MarketplaceService.ProcessReceipt` is the source of truth for developer-product fulfillment;
- validate player/user identity and product ID;
- grant exactly once even if Roblox retries the receipt;
- persist the grant before acknowledging success;
- return `NotProcessedYet` when a safe grant cannot be completed;
- never treat a client purchase-finished event as proof of entitlement.

Official reference:
- https://create.roblox.com/docs/production/monetization/developer-products

## 7. Randomized-item compliance

If Robux or paid in-game currency can lead to a random reward, Roblox's paid-random-item rules apply.

This includes:
- eggs/capsules/chests/spins;
- paid rerolls;
- paid luck modifiers;
- pity/rate-up systems connected to paid random outcomes.

Project rule for v1: **no paid randomized rewards**.

If added later:
- disclose all possible outcomes and actual numerical odds before purchase;
- dynamically show altered odds when luck modifiers apply;
- call `PolicyService:GetPolicyInfoForPlayerAsync()` and respect `ArePaidRandomItemsRestricted` and `IsPaidItemTradingAllowed`.

Free gameplay random rewards that are not purchased with Robux or Robux-purchasable currency do not have the same odds-disclosure requirement, but should still be designed transparently.

Official reference:
- https://create.roblox.com/docs/production/monetization/paid-random-items

## 8. Data persistence

Use `DataStoreService` for durable state and `MemoryStoreService` only for temporary/high-frequency cross-server state.

Project persistence rules:
- one or a few fixed data stores;
- one or a few deterministic keys per player;
- keep atomically related player state together when practical;
- schema version every profile;
- sanitize and clamp loaded values;
- never expose DataStore access to clients;
- protect production data from Studio tests by default;
- use `UpdateAsync`-style conflict-safe writes where appropriate;
- design receipt state so duplicate grants are impossible;
- use MemoryStore for ephemeral coordination, not permanent inventory/currency.

Official references:
- https://create.roblox.com/docs/cloud-services/data-stores
- https://create.roblox.com/docs/cloud-services/data-stores/best-practices
- https://create.roblox.com/docs/cloud-services/memory-stores
- https://create.roblox.com/docs/cloud-services/data-stores-vs-memory-stores

## 9. Security model

Roblox's security guidance assumes the client is hostile.

An exploiter can:
- decompile replicated LocalScripts/ModuleScripts;
- manipulate local code and state;
- fire/invoke remotes with arbitrary arguments and frequency;
- manipulate character movement/physics;
- obtain network ownership of unanchored assemblies;
- trigger client-facing interactions such as prompts in unexpected ways.

Therefore the server must own all valuable outcomes.

Project rule:
- client sends intent, never authoritative rewards/results;
- validate type, bounds, finite numeric values, ownership, prerequisites, proximity/context, cooldowns, and rate limits;
- server determines prices and rewards;
- prompts, click detectors, touch events, and drag interactions receive the same threat treatment as remotes;
- avoid remotes that accept arbitrary Instance paths/references to modify the DataModel;
- use `UnreliableRemoteEvent` only for noncritical high-frequency data where loss/order is acceptable.

Official references:
- https://create.roblox.com/docs/scripting/security/client-server-boundary
- https://create.roblox.com/docs/scripting/security/security-tactics
- https://create.roblox.com/docs/scripting/events/remote

## 10. Mobile and multi-platform UX

Roblox strongly recommends multi-platform design, with particular attention to its large mobile audience.

Project rule:
- every core action must work on touch, mouse/keyboard, and gamepad where supported;
- UI must reflow responsively rather than simply scale down desktop layouts;
- frequently used mobile actions should stay in comfortable thumb zones;
- avoid critical UI under default mobile controls/reserved zones;
- use input-specific prompts/hints;
- large, legible tap targets and text;
- test low-resolution and small-screen layouts before polishing desktop-only UI.

Official references:
- https://create.roblox.com/docs/production/publishing/adaptive-design
- https://create.roblox.com/docs/ui
- https://create.roblox.com/docs/ui/position-and-size

## 11. Performance rules

Performance is a product requirement because long join times, frame drops, and memory pressure hurt retention and shrink the addressable mobile audience.

Project rule:
- target fast join-to-play time;
- avoid unnecessary high-resolution textures and excessive unique meshes;
- pool/reuse repetitive effects and world objects when useful;
- avoid unbounded per-frame loops;
- profile server and client regularly rather than guessing;
- consider instance streaming as the world grows;
- allow appropriate mesh/render fidelity reduction;
- disable unnecessary shadows on dense repeated factory assets;
- budget robot counts, particles, conveyor objects, and physics from the start.

Official references:
- https://create.roblox.com/docs/performance-optimization
- https://create.roblox.com/docs/performance-optimization/improve

## 12. LiveOps and scalable content

Roblox's game-design documentation explicitly treats LiveOps, content updates, quests/dailies, season-pass design, virtual economies, and analytics as long-term product systems.

Project rule:
- every core system should support data-driven content expansion;
- new zones/robots/materials/upgrades should require mostly configuration + assets;
- do not create a bespoke new code path for every event;
- reserve season-pass/subscription complexity until the repeat loop is validated;
- design daily/weekly goals after the base loop proves it can retain players without artificial chores.

Official reference hub:
- https://create.roblox.com/docs/production/game-design

## 13. Current project implications

For the current `Scrap-to-Bot Factory` candidate, the official guidance supports the following MVP structure:

**Minute-to-minute:** move through a compact salvage area and collect/process scrap.

**Repeated action set:** collect -> process -> assemble/reveal -> assign bot -> earn -> upgrade.

**Progression engine:** better tools/processors, higher-value robot families, factory automation/capacity, new salvage zones, collection index, and later prestige.

### MVP must include

- server-authoritative economy;
- safe persistent profiles;
- idempotent purchase receipts;
- analytics funnels/economy events from day one;
- responsive mobile UI;
- clear first-session goals;
- visible physical factory growth;
- free random collectible reveals only at launch;
- direct/guaranteed paid products rather than paid lootboxes;
- enough content for repeat-session testing, but not a giant map.

## 14. Source hierarchy

Use sources in this order when making implementation decisions:

1. Roblox Creator Hub / official API reference / official policy pages;
2. Roblox Developer Forum announcements by Roblox staff for current platform changes;
3. our own live analytics and experiment results;
4. direct competitor observation and public market data;
5. experienced developer/community discussion;
6. old scripts/tutorials only as historical examples or threat cases.

If an older tutorial or community post conflicts with current Creator Hub documentation, follow Creator Hub.
