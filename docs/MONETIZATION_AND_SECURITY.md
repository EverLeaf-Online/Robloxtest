# Monetization and Security Architecture

Research baseline: 2026-09-16

## Monetization principles

The revenue model should monetize **speed, convenience, capacity, customization, and recurring engagement** rather than blocking the base game.

Roblox discovery currently includes spend days per user and Robux spent per user as recommendation signals, but those signals sit alongside stronger engagement and retention signals. Monetization that damages retention can reduce discovery.

Primary source: https://create.roblox.com/docs/discovery

## Roblox monetization surfaces

### Passes

Permanent one-time upgrades. Roblox currently documents a 70% creator share when selling your own passes.

Potential launch candidates:

- 2x production income;
- faster processing;
- extra robot work slots;
- larger material storage;
- auto-collect / convenience;
- VIP cosmetics + moderate utility bundle.

Source: https://create.roblox.com/docs/monetize-experiences

### Developer products

Repeatable purchases. Good candidates:

- guaranteed material packs;
- temporary production boosts;
- instant repair/process tokens;
- event currency bundles;
- guaranteed direct robot/component bundles;
- server-wide temporary boost products.

Do not grant from client-side purchase-finished events. Use server-side receipt processing only.

Source: https://create.roblox.com/docs/production/monetization/developer-products

### Subscriptions

Recurring monthly value should support returning players rather than replace the main progression loop.

Potential subscription value:

- daily premium utility allowance;
- monthly exclusive cosmetic factory theme;
- extra queue/assignment slot;
- modest persistent convenience bonus;
- subscriber-only cosmetic robot parts;
- no exclusive progression wall.

Roblox documentation currently states:

- Robux-priced subscriptions pay creators 70% each month.
- For local-currency subscriptions, creators receive the equivalent of 70% in month one and 100% from month two onward after the documented platform structure.

Source: https://create.roblox.com/docs/production/monetization/subscriptions

### Rewarded video ads

Rewarded video can monetize non-spenders after eligibility is reached.

Current eligibility includes:

- public unrestricted experience;
- complete/approved maturity questionnaire;
- at least 2,000 unique visitors per month;
- publisher age 13+;
- ID verification and 2FA;
- user-initiated ads with clear disclosure.

Roblox recommends meaningful rewards roughly equivalent to 3-10 Robux and explicitly prohibits randomized rewarded-video rewards.

Best candidate placements:

- optional temporary 2x production;
- one guaranteed material pack;
- instant completion of a current process;
- one extra daily salvage attempt.

Source: https://create.roblox.com/docs/production/promotion/rewarded-video-ads

### Managed pricing / regional pricing

Use Managed Pricing once product prices exist. Dynamic product-price UI must not hardcode Robux values.

Roblox's price optimization feature generally needs very large transaction volume; documentation says successful tests typically require roughly 60,000 transactions over the previous 30 days.

Sources:
- https://create.roblox.com/docs/production/monetization
- https://create.roblox.com/docs/production/monetization/price-optimization

### Creator Rewards

Creator Rewards can add revenue from qualifying user behavior, but the game should never be stretched artificially to chase a reward condition. The product needs natural 10+ minute engagement because the player has meaningful progression goals.

Source: https://create.roblox.com/docs/creator-rewards

## DevEx economics

Current Roblox documentation lists:

- standard DevEx rate: **$0.0038 USD per Earned Robux**;
- 30,000 Earned Robux = **$114 USD** at the standard rate;
- eligible purchases from U.S. users age 18+ who completed qualifying age verification can receive a higher **$0.0054** exchange rate for certain earned Robux from passes, developer products, subscriptions, and private servers.

Source: https://create.roblox.com/docs/production/monetization/developer-exchange

Revenue projections must use **Earned Robux**, not gross checkout price, and must account for acquisition/asset/development costs before calling revenue profit.

## Paid random items

If Robux, or currency acquired with Robux, is used to obtain a randomized outcome, Roblox requires the actual numerical odds of all outcomes to be displayed before purchase.

This also applies to:

- paid eggs/chests/spins;
- paid reroll tokens;
- luck boosts affecting paid random outcomes;
- pity/rate-up mechanics tied to paid random systems.

PolicyService must also be used because some users cannot access paid random items or paid-item trading.

Source: https://create.roblox.com/docs/production/monetization/paid-random-items

### Recommended launch policy

Avoid premium lootboxes at launch. Prefer guaranteed purchases and progression acceleration. This reduces compliance complexity and makes value easier to communicate.

## Ethical/compliance guardrails

Do not use:

- fake countdown timers;
- fake scarcity;
- misleading "last chance" prompts;
- rewards that are not actually granted;
- prompts suggesting free Robux/money;
- forced rewarded-video gates;
- hidden random-item odds;
- client-side purchase confirmation as proof of payment.

Source: https://create.roblox.com/docs/production/monetization

# Security architecture

## Threat model

The reference repository `https://github.com/retpirato/Roblox-Scripts` contains historical exploit scripts that demonstrate common attack patterns:

- noclip / collision removal;
- spoofed RemoteEvent calls;
- negative purchase values;
- direct SetStat calls;
- arbitrary gear requests;
- impossible health values;
- movement/stat manipulation.

It should be used only to design tests and defenses.

## Rule: server owns all valuable state

The server must own and calculate:

- currency;
- item ownership;
- robot ownership/rarity/variant;
- production rates;
- upgrade prices;
- purchase rewards;
- prestige/rebirth;
- inventory capacity;
- crafting outcomes;
- quest/event completion;
- trades/auctions if added later.

Clients request actions; clients do not declare outcomes.

Roblox security source: https://create.roblox.com/docs/scripting/security/client-server-boundary

## Remote validation requirements

Every economy-affecting remote should validate:

- argument type;
- finite numbers only (reject NaN / infinity);
- integer/range rules where appropriate;
- ownership;
- current server-side state;
- cooldown/rate limit;
- distance/proximity where physical interaction matters;
- prerequisite unlocks;
- requested quantity limits;
- transaction uniqueness.

Never accept a price from the client. Client sends an item/action identifier; server looks up the authoritative price and performs the transaction atomically.

## Marketplace receipts

Developer products must use `MarketplaceService.ProcessReceipt` / current supported receipt handling and must be idempotent.

Requirements:

1. validate Player/User ID and Product ID;
2. record receipt/purchase identity durably;
3. prevent duplicate grants if a receipt is retried;
4. only acknowledge purchase after the reward is durably granted;
5. return NotProcessedYet when the player/data session is unavailable;
6. never trust `PromptProductPurchaseFinished` as proof of payment.

Source: https://create.roblox.com/docs/scripting/security/client-server-boundary

### Useful historical code

The old Tiny Planet implementation at commit `79875d7599e4ddd44d5433e9683ed5c1e07335ff` already included:

- receipt purchase IDs;
- duplicate-grant checks;
- server-side product ID routing;
- retrying persistence before acknowledging a previously granted receipt;
- protected `NotProcessedYet` behavior when data was unavailable.

We can preserve these patterns while rewriting them for the new data model.

## Persistence

Use DataStoreService for durable player state and MemoryStore only for temporary/high-frequency cross-server coordination where needed.

Roblox source: https://create.roblox.com/docs/cloud-services/data-stores

Persistence requirements:

- schema versioning and migrations;
- data sanitization on load;
- bounds on all numeric data;
- session ownership/locking strategy before trading exists;
- dirty-state save coalescing;
- retry/backoff for transient failures;
- graceful protected mode if cloud data cannot load safely;
- receipt state separated or structured so duplicate purchase grants cannot occur;
- Studio testing isolated from production data by default.

The old `DataManager.lua` at commit `79875d7` is a useful reference for sanitization, revision checks, backup recovery, and Studio persistence bypass, but it should be reviewed and simplified for the new project rather than copied blindly.

## Trading / auction warning

Do not ship player-to-player trading in v1. Trading adds a large exploit/duplication surface and paid-item regulatory obligations. If it becomes strategically valuable later, design it as an atomic transaction system first, then add UI.

Roblox specifically warns about race-condition trade duplication when saves fail after an exchange.

Source: https://create.roblox.com/docs/scripting/security/client-server-boundary
