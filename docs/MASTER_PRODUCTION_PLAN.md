# Scrap-to-Bot Factory — Master Production Plan

Status: **Production planning lock**  
Baseline: **2026-09-16**

This document turns the research phase into an execution plan. Gameplay implementation should follow this plan unless playtest data justifies a deliberate change.

## 1. Product lock

### Working title

**Scrap-to-Bot Factory**

The shipping title can change after packaging tests, but the product fantasy is locked for the first prototype.

### One-sentence pitch

Collect junk and machine parts, process them through a growing factory, assemble increasingly rare robots, and use those robots to automate and expand the factory.

### Core promise

Every meaningful progression step should become visible in the world: more machines, faster conveyors/processors, larger storage, more working robots, expanded plot space, better salvage zones, or visually distinct factory tiers.

### Design pillars

1. Understandable in seconds.
2. First meaningful action almost immediately.
3. Physical progression, not number-only progression.
4. Frequent reveal/rarity moments.
5. Collection with gameplay purpose.
6. Personal factory that shows progress.
7. Social comparison/cooperation without destructive griefing.
8. Content added mostly through configuration and reusable assets.
9. Server-authoritative economy and progression.
10. Mobile-first interaction and performance.

## 2. Launch platform targets

### Required at first playable

- PC keyboard/mouse
- mobile touch

### Required before public launch

- gamepad navigation/input pass
- small-screen UI pass
- low-end mobile performance pass

Console-specific polish can follow after the core loop proves itself, but the UI architecture must not block gamepad support.

## 3. First playable scope

The graybox must contain only enough content to validate the full loop.

### World

- one shared spawn / orientation area;
- one compact salvage field;
- one row/ring of personal factory plots;
- visible locked gate/route to the next salvage zone;
- simple social sightlines so players can see other factories working.

### Player plot

Each player receives one personal plot containing:

- material storage;
- one starter processor;
- one starter assembler;
- robot work pads;
- sell/recycle station;
- upgrade console/pads;
- collection/index display access;
- reserved expansion sockets for later machines.

### Materials

Three launch materials:

1. Scrap Metal — common base resource.
2. Wiring — secondary resource.
3. Power Core Fragments — uncommon bottleneck resource.

Names may change, but the three-resource role structure is fixed.

### Machines

1. Processor — converts raw salvage into usable components.
2. Assembler — consumes processed materials and creates a robot reveal.

Graybox upgrades:

- Processor Speed I/II/III
- Assembler Speed I/II/III
- Storage I/II/III
- Robot Work Slot unlocks

### Robots

First playable target: **12 outcomes** built from a modular kit rather than 12 completely bespoke rigs.

Rarity tiers:

- Common
- Uncommon
- Rare
- Epic

Every robot has:

- robot ID;
- family;
- rarity;
- visual variant data;
- production stat;
- optional specialization tag;
- collection-index state;
- sell/recycle value.

No paid random robot rolls in v1.

## 4. Core gameplay state machine

The intended loop is:

1. **Collect** salvage from an authoritative world node.
2. **Deposit/process** salvage at the player's processor.
3. **Assemble** a robot when requirements are met.
4. **Reveal** the server-selected robot result.
5. **Assign** useful robots to work pads.
6. **Earn** server-calculated production income/material bonuses.
7. **Sell/recycle** duplicates the player does not want.
8. **Upgrade** machines, capacity, storage, or work slots.
9. **Unlock** stronger salvage zones and new bot families.
10. **Prestige** later into a higher factory tier with permanent bonuses.

The client requests actions; the server validates prerequisites and calculates all durable outcomes.

## 5. First-session progression plan

These are initial tuning targets for the graybox and must be adjusted from playtest data.

### 0:00–0:30 — prove the fantasy

Player should:

- spawn facing the salvage route and factory plot;
- receive a starter collector automatically;
- collect first scrap within ~10 seconds;
- see material feedback immediately;
- be directed spatially, not through a long tutorial panel.

### 0:30–1:30 — complete the first loop

Player should:

- process their first salvage batch;
- feed the assembler;
- receive the first robot reveal;
- see exactly why the robot matters.

The first robot is guaranteed to be usable. No dead first roll.

### 1:30–3:00 — physical progression

Player should:

- assign the robot to a visible work pad;
- see it animate/work;
- receive first automated income;
- afford the first meaningful upgrade.

### 3:00–7:00 — collection tension

Player should:

- assemble multiple robots;
- encounter the rarity system;
- understand duplicate sell/recycle;
- see the collection index;
- begin choosing between machine speed, storage, and another work slot.

### 7:00–15:00 — build identity

Player should:

- have several visible factory improvements;
- unlock at least one additional work slot or machine tier;
- see progress toward the next salvage zone;
- begin forming a preferred bot lineup;
- encounter a rotating order/goal or server event teaser.

### 15:00–30:00 — establish return motivation

Player should:

- unlock or nearly unlock the second salvage zone;
- see a new material/bot family ahead;
- understand long-term factory tier/prestige progression;
- have at least one collection gap worth returning for;
- see daily/return systems only after the core loop is understood.

Prestige should **not** be forced into the first session if that weakens the base loop. The first prestige target can be tuned after graybox data.

## 6. Economy design rules

### Currency

Primary soft currency: **Credits** (working name).

Credits come from:

- robot production;
- duplicate selling/recycling;
- goals/orders;
- limited free rewards.

Credits leave through:

- machine upgrades;
- storage upgrades;
- work-slot unlocks;
- zone unlocks;
- future cosmetic/utility sinks.

### Economy invariants

- no client-supplied price;
- no client-supplied reward amount;
- no client-supplied rarity;
- no client-supplied production multiplier;
- no negative prices or quantities;
- all numbers validated as finite and bounded;
- valuable transactions are atomic/idempotent where duplicates could matter;
- production uses server timestamps and authoritative assigned robots;
- offline income is capped when introduced;
- no trading in v1.

### Early balance philosophy

The first session should be acceleration-heavy without becoming meaningless:

- first upgrades cheap enough to demonstrate growth quickly;
- later upgrades branch into meaningful choices;
- resource bottlenecks rotate rather than all scaling identically;
- no early forced waiting;
- automation enhances active play instead of replacing it immediately.

## 7. Data model

One authoritative profile per player.

Proposed top-level schema:

```text
Version
Revision
Currencies
  Credits
Materials
  ScrapMetal
  Wiring
  PowerCoreFragments
Robots
  OwnedByUid
  NextUid
Assignments
  WorkPads
Machines
  ProcessorLevel
  AssemblerLevel
  StorageLevel
Progression
  Zone
  FactoryTier
  PrestigeCount
Collection
  RobotSeen
  RobotOwned
Tutorial
  Milestones
Entitlements
  CachedPassFlags (non-authoritative convenience only)
Receipts
  RecentPurchaseIds
Stats
  LifetimeCredits
  LifetimeRobotsBuilt
Timestamps
  LastJoin
  LastSave
  LastProductionTick
Settings
  Audio
  Haptics
  UI
```

Rules:

- schema versioning from day one;
- sanitize loaded data;
- clamp all economic values;
- preserve unknown/newer fields safely during migrations where practical;
- profile session-locking/conflict prevention;
- save coalescing;
- periodic saves + critical transaction/checkpoint saves;
- bounded receipt history or durable receipt strategy;
- no Studio production-store writes by default.

Persistence implementation choice must be proven with a small spike before full gameplay: ProfileStore or a deliberately minimal custom layer using current DataStore best practices.

## 8. Server architecture

Avoid a large framework dependency. Use explicit service modules.

### Server services

- `DataService` — profile load/save/session lifecycle/migrations.
- `PlayerStateService` — authoritative player session state.
- `SalvageService` — spawn/claim/cooldown/collection validation.
- `ProcessingService` — processor queues and completion.
- `RobotService` — robot generation, ownership, reveal result, assignment.
- `FactoryService` — machine levels, plot state, work pads, production.
- `EconomyService` — credit/material mutations and transaction helpers.
- `ProgressionService` — zones, milestones, factory tier/prestige.
- `MonetizationService` — passes/products/receipts.
- `AnalyticsService` — funnels, economy events, progression events.
- `AntiExploitService` — rate limits, anomaly logging, reusable validation.
- `WorldService` — plots, zone state, shared world events.

Services should expose narrow methods and not directly mutate each other's private tables.

## 9. Client architecture

### Controllers

- `InputController`
- `InteractionController`
- `FactoryController`
- `SalvageController`
- `RobotController`
- `UIController`
- `AudioController`
- `EffectsController`
- `TutorialController`

The client owns presentation, prediction where harmless, animation, input, and UX. It does not own economic truth.

## 10. Networking contract

Remote APIs should be action-oriented rather than generic mutation endpoints.

Examples:

- `RequestCollect(nodeId)`
- `RequestProcess(recipeId, quantity)`
- `RequestAssemble(assemblerId)`
- `RequestAssignRobot(robotUid, workPadId)`
- `RequestSellRobot(robotUid)`
- `RequestUpgrade(upgradeId)`
- `RequestUnlockZone(zoneId)`
- `RequestPrestige()`

Server validates:

- argument types;
- finite/integer bounds;
- profile readiness;
- ownership;
- current zone/state;
- distance/context where physical interaction matters;
- required materials/currency;
- cooldown/rate limit;
- request concurrency;
- authoritative config lookup.

Never expose a generic `SetStat`, `GiveItem`, `SetCurrency`, arbitrary Instance mutation, or client-priced purchase remote.

## 11. Security acceptance criteria

Before public testing, manually or automatically verify that attempts to:

- spam collection calls;
- collect nonexistent nodes;
- collect distant nodes;
- submit NaN/infinity/negative quantities;
- replay upgrade requests;
- sell the same robot twice;
- assign robots not owned;
- skip zones;
- spoof prices;
- spoof rarity/reveal result;
- forge product-completion events;
- disconnect during valuable transactions;

cannot create durable invalid value.

Client anti-cheat is supplemental only.

## 12. UI plan

### HUD

Keep the always-visible HUD small:

- Credits
- material/storage summary
- current objective
- compact shop/menu access

### Primary screens

- Robot Collection
- Factory Upgrades
- Shop
- Index
- Settings
- later: Daily/Weekly Goals

### UX rules

- no giant tutorial modal at spawn;
- one dominant CTA at a time during FTUE;
- buttons sized for touch;
- critical interaction not hover-dependent;
- responsive reflow for small screens;
- UI never covers Roblox movement controls;
- gamepad focus architecture supported before public launch.

UI framework decision is a prototype task: compare plain Roblox UI, React Luau, and Fusion for developer velocity, performance, testing, and maintainability before committing the whole game.

## 13. Art and asset plan

### Visual direction

Stylized, readable, colorful industrial sci-fi rather than realistic factory simulation.

### Modular robot kit

Build reusable pieces:

- 3–4 body archetypes;
- 3–4 heads;
- 3–4 arm/tool sets;
- wheel/leg/hover locomotion variants;
- accessories/antennae;
- rarity materials/emissive accents;
- decals/face variants.

Twelve launch outcomes should be combinations/variants from this kit, not twelve unrelated models.

### Factory kit

Reusable modular assets:

- floor/wall panels;
- conveyor modules;
- pipes/cables;
- processor shell;
- assembler shell;
- storage bins;
- work pads;
- upgrade visual add-ons;
- signs/lights;
- salvage props.

Only original, appropriately licensed, or Roblox-permitted assets may ship.

## 14. Performance budgets

Initial targets to validate rather than blindly assume:

- fast join-to-input path;
- stable 60 FPS target on representative desktop hardware;
- playable stable frame rate on target low/mid mobile hardware;
- bounded active salvage nodes;
- bounded visible working robots per plot/server;
- pooled effects;
- no unbounded Heartbeat/RenderStepped work;
- avoid unique high-resolution textures for repeated machines;
- use streaming if world scale warrants it;
- profile before adding complex physics/conveyors.

A specific target-phone/device matrix must be established before public release.

## 15. Analytics implementation

### Onboarding funnel

1. `session_start`
2. `first_input`
3. `first_scrap_collected`
4. `first_process_started`
5. `first_robot_revealed`
6. `first_robot_assigned`
7. `first_income_claimed`
8. `first_upgrade`
9. `first_zone_goal_seen`
10. `first_zone_unlock`

### Monetization funnel

1. `shop_opened`
2. `product_viewed`
3. `purchase_prompted`
4. `purchase_receipt_granted`

### Progression funnel

1. first upgrade
2. first automation
3. second production line/work-slot milestone
4. first rare robot
5. first prestige eligible
6. first prestige

Track economy sources/sinks separately.

## 16. Monetization plan

Monetization code/hooks exist early; final prices/offers are tuned after loop validation.

### Pass candidates

- Double Production
- Faster Processing
- Extra Work Slots
- Larger Material Storage
- Auto-Collect convenience
- VIP cosmetics + moderate utility

### Developer Product candidates

- Starter Pack
- guaranteed material pack
- timed production boost
- instant process token
- guaranteed event bundle
- server-wide boost

### Later, not launch-critical

- subscription
- rewarded video after eligibility
- regional/managed pricing
- price optimization after enough transaction volume

### Rules

- `MarketplaceService.ProcessReceipt` is authoritative for developer-product grants;
- receipt grants are idempotent;
- no paid randomized robot system at launch;
- no fake scarcity/countdowns;
- free progression remains viable.

Do not reuse monetization IDs from any other EverLeaf project.

## 17. Social plan

Graybox social features are lightweight:

- players can see other factories;
- optional visit/inspect interaction;
- server-wide visual event can involve everyone.

Post-validation candidates:

- base likes;
- cooperative rush orders;
- friend production bonus with reasonable cap;
- collection showcase;
- server event goals;
- races/challenges using owned robots.

No trading and no irreversible stealing/griefing in v1.

## 18. LiveOps/content pipeline

The data model must allow new content without service rewrites.

Data-driven definitions:

- materials;
- salvage nodes;
- recipes;
- machines;
- upgrades;
- robot families/variants;
- rarity tables;
- zones;
- goals/orders;
- events;
- shop bundles.

A normal update should be achievable by adding configs/assets and limited presentation code rather than creating a new backend system.

## 19. Test plan

### Unit tests

At minimum:

- economy mutations;
- price lookup;
- upgrade requirements;
- robot generation bounds;
- duplicate-safe sell operations;
- progression gates;
- receipt idempotency;
- schema migration/sanitization;
- offline/production calculations when added.

### Integration tests

- join/load/leave/save;
- two-player plot allocation;
- collection claim contention;
- process/assemble flow;
- assignment/production;
- reconnect persistence;
- purchase receipt retry;
- malformed/spam remote attempts.

### UI tests

Automate critical flows where practical:

- shop open/render;
- upgrade availability;
- collection/index state;
- first-session objective transitions;
- responsive layouts.

### Manual playtest gates

- desktop fresh account;
- touch device fresh account;
- poor network simulation;
- reconnect during save-sensitive states;
- server with multiple plots active;
- low-end performance profile.

## 20. Production phases and exit criteria

### Phase A — Architecture spikes

Deliverables:

- Rojo/Rokit/Wally/toolchain skeleton;
- persistence spike;
- networking/validation helpers;
- UI-framework comparison spike;
- automated test proof-of-concept.

Exit only when the chosen foundation is understood and testable.

### Phase B — Graybox vertical slice

Deliver complete loop:

collect -> process -> assemble -> reveal -> assign -> produce -> sell -> upgrade -> zone goal.

Exit only when a new player can complete the loop without developer explanation.

### Phase C — Secure persistence + analytics

Add:

- durable profiles;
- migrations/sanitization;
- all first-session funnel events;
- economy logging;
- exploit validation suite.

Exit only when reconnect/retry/abuse tests do not duplicate value.

### Phase D — Content/visual pass

Add:

- modular robot kit;
- factory kit;
- 12 bot outcomes;
- readable salvage zone;
- first major plot transformation;
- responsive polished HUD/core screens.

Exit only when the game communicates its premise visually in screenshots/video.

### Phase E — Monetization integration

Add configuration-driven passes/products with IDs left unset until created for this specific experience.

Exit only when receipt retry/idempotency tests pass and no purchase relies on client confirmation.

### Phase F — Closed playtest

Observe new players without instruction.

Fix comprehension, pacing, UI, performance, and balance issues before public acquisition.

### Phase G — Small public validation

Measure actual Roblox cohorts and similar-experience benchmarks.

Do not scale paid acquisition until the core loop and retention are competitive or clearly improving.

### Phase H — Scale or pivot

Scale content/acquisition only if the loop validates.

If it does not, preserve reusable infrastructure and pivot the theme/loop instead of forcing months of content into a weak product.

## 21. Definition of done for first public validation build

The build is ready for a small public test only when:

- fresh players can understand and complete the core loop;
- the first session has no forced idle wall;
- progression visibly changes the factory;
- 12 robot outcomes and four rarities work;
- collection/index works;
- save/load/reconnect are robust;
- every valuable remote is server validated/rate limited;
- receipt processing is idempotent;
- onboarding/progression/economy analytics fire;
- mobile controls/UI work;
- critical desktop/mobile performance is profiled;
- no borrowed/provenance-unclear assets ship;
- monetization offers are optional acceleration/convenience rather than required to make progress;
- packaging accurately depicts real gameplay.

## 22. Immediate implementation order after planning

1. Repository/toolchain skeleton.
2. Shared typed configs and validation utilities.
3. Persistence spike + tests.
4. Server service/bootstrap skeleton.
5. Plot allocation/world graybox.
6. Salvage collection.
7. Processing.
8. Robot assembly/reveal.
9. Robot ownership/assignment/production.
10. Economy/upgrades.
11. Zone gating.
12. Core UI/FTUE.
13. Analytics.
14. Monetization hooks/receipts.
15. Abuse/integration tests.
16. Art/content replacement of graybox.
17. Closed playtest fixes.
18. Small public validation.

## Final production rule

**No system is considered complete because code exists. It is complete when its acceptance tests pass, it survives the hostile-client threat model, it works on target input/device classes, and it supports the intended player/business metric.**
