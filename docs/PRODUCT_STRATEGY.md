# Product Strategy

Status: **Research recommendation — not yet production lock**

## Business objective

Build a Roblox simulation product that maximizes the probability of positive return on development time by combining:

- low initial production scope;
- immediately understandable gameplay;
- strong repeat-session progression;
- multiple legitimate monetization surfaces;
- cheap recurring content updates;
- strong visual packaging for Home recommendations and short-form video.

The design is intentionally **profit-first**, but revenue depends on player satisfaction and retention. Roblox's discovery system measures engagement, repeat play, social play, and spending together, so a game that monetizes aggressively but causes high bounce or weak return behavior is strategically bad.

## Design pillars

### 1. One-sentence premise

A player should understand the fantasy without a tutorial paragraph.

### 2. Physical transformation

Numbers alone are not enough. Upgrades should visibly change the player's tools, base, machines, collection, or world.

### 3. Frequent reveal moments

Each short loop should have anticipation: what item, part, rarity, mutation, quality, or variant did I get?

### 4. Collection with purpose

Collected objects should do something: generate income, improve production, fill an index, unlock bonuses, decorate a base, or feed crafting/merging.

### 5. Persistent personal space

The player's base should communicate progress instantly when they return or when another player visits.

### 6. Social without mandatory griefing

Current "steal" games prove social stakes can be powerful, but we do not need destructive PvP. Safer durable options include:

- visiting and liking bases;
- server-wide resource events;
- auctions / market events;
- cooperative rush orders;
- races/challenges using owned collectibles;
- gifting temporary boosts;
- leaderboards with no irreversible loss.

### 7. Content should be configuration-driven

New items, rarities, zones, machines, recipes, and events should mostly be data/assets plugged into existing systems.

## Concept shortlist

### A. Scrap-to-Bot Factory — CURRENT RECOMMENDATION

**Pitch:** Collect junk and machine parts, process them through your growing factory, assemble increasingly rare robots, and use those robots to automate and expand the factory.

Core loop:

1. Salvage scrap / parts.
2. Feed materials into a processing machine.
3. Assemble a robot or valuable machine component.
4. Reveal quality/rarity/variant.
5. Assign robots to production stations or display/sell duplicates.
6. Earn cash/materials over time.
7. Upgrade machines, storage, speed, and plot size.
8. Unlock new salvage zones and robot families.
9. Prestige into a higher factory tier with permanent bonuses.

Why it fits the research:

- instantly visual and easy to understand;
- combines tactile collecting with factory growth;
- rarity/reveal supports collection;
- robots create a pet-like emotional/collection layer without copying a pet simulator;
- robots can visibly work, making progression feel physical;
- easy to expand with new parts, bot sets, mutations, zones, and machine skins;
- supports short clips showing junk -> machine -> rare robot -> upgraded factory;
- monetization naturally targets bottlenecks such as production slots, processing speed, storage, convenience, and cosmetics.

Main risk: it can become too asset-heavy if every bot is bespoke. Mitigation: modular robot construction using reusable bodies/heads/arms/accessories and data-driven variants.

### B. Restore & Resell Workshop

Find damaged objects, clean/repair them, reveal value/rarity, display the best pieces, sell duplicates, and expand a restoration shop/museum.

Strengths: extremely understandable and satisfying reveal loop.  
Risk: current Dig & Clean / storage-hunting games already occupy adjacent territory, so differentiation would need to be very strong.

### C. Micro Factory Collector

Produce increasingly unusual products on a physical conveyor network, collect rare product variants, fulfill rotating orders, automate lines, and prestige.

Strengths: lowest technical risk and strong physical progression.  
Risk: a plain factory fantasy is less aligned with current high-traffic collection/reveal games unless the product collection layer is unusually strong.

## Why Scrap-to-Bot is ahead

It combines the best durable elements found in current winners without copying their surface theme:

- simulator simplicity;
- pet-like collection;
- factory/tycoon visible growth;
- rarity excitement;
- passive income;
- collection index;
- easy live-ops additions;
- social show-off value.

## First playable scope

The first validation build should be intentionally small:

- 1 compact salvage area;
- 1 personal factory plot;
- 3 material types;
- 1 processor;
- 1 assembler;
- 8-12 modular robot outcomes;
- 4 rarity tiers;
- 3 meaningful machine upgrades;
- robot assignment to production slots;
- sell duplicate flow;
- collection index;
- save/load;
- basic shop hooks but no need to enable every monetization product during internal testing;
- mobile + desktop controls from the start.

## First-session pacing hypothesis

These are prototype goals to test, not platform-wide benchmark claims:

- spawn to first action: <10 seconds;
- first completed salvage/process loop: <45 seconds;
- first factory upgrade: ~1-2 minutes;
- first rarity/reveal excitement: within first few minutes;
- first new zone / major visual change: within first session;
- clear next goal visible at all times;
- enough layered progression for a natural 10+ minute session without forced waiting.

## Long-term progression structure

### Short loop: seconds

Collect -> process -> reveal -> assign/sell.

### Session loop: minutes

Upgrade factory -> unlock better scrap -> complete orders -> fill collection gaps.

### Multi-day loop

New robot families -> prestige/factory tier -> daily/weekly objectives -> rotating world events.

### Seasonal loop

Limited cosmetic bot sets, themed salvage zones, special guaranteed reward tracks, event challenges, and factory decorations.

Avoid making paid random outcomes the centerpiece. If randomized paid items are ever introduced, all Roblox odds and PolicyService requirements must be implemented first.

## Update strategy

A successful simulator must be cheap to feed with content. Planned update units should be reusable:

- 5-10 new robot parts/variants;
- one new salvage zone;
- one new machine tier;
- one new temporary world event;
- collection rewards;
- cosmetic factory theme;
- new guaranteed shop bundle.

The core systems should not need rewriting for each update.

## Packaging strategy

Icon/thumbnail/video must communicate:

**junk/scrap -> machine -> rare robot -> huge upgraded factory**

The title should describe the action/fantasy, not internal lore. Roblox says non-unique games and mismatched metadata can lose recommendation exposure, so visuals and naming must be original and accurately represent gameplay.

Primary source: https://create.roblox.com/docs/discovery
