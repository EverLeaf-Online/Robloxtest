# Validation Plan

Goal: validate the game economically before investing in a large content build.

## Phase 0 — Paper/product validation

Before production:

- lock the one-sentence pitch;
- lock the first-session loop;
- define every launch monetization surface;
- define the first 30 minutes of progression;
- define what changes physically on the player's plot;
- define the first-day return hook;
- define 3-4 weeks of cheap update units;
- produce packaging concepts that visibly explain the loop.

Current candidate: **Scrap-to-Bot Factory**.

## Phase 1 — Graybox prototype

Build only enough to answer:

1. Is collecting scrap satisfying?
2. Is processing/assembling easy to understand without explanation?
3. Does the robot reveal feel exciting?
4. Is assigning robots to production intuitive?
5. Does the factory visibly improve quickly enough?
6. Does the player always know the next goal?
7. Does the loop work comfortably on mobile?

No large world. No trading. No complex seasonal system. No giant cosmetic catalog.

### Prototype instrumentation

Log funnel events server-side where possible:

- session_start;
- first_input;
- first_scrap_collected;
- first_process_started;
- first_robot_revealed;
- first_robot_assigned;
- first_sale;
- first_upgrade;
- first_zone_unlock;
- first_shop_open;
- purchase_prompted;
- purchase_completed;
- prestige_unlocked;
- session_end_reason / last completed milestone where measurable.

Use Roblox analytics plus internal funnel events so we can locate exact drop-off points.

## Phase 2 — Closed playtest

Test with people who did not build the game.

Do not explain how to play before the test. Observe whether packaging, environment, UI, and prompts teach the loop themselves.

Questions to answer:

- Can a new player describe the game after 30 seconds?
- How long until their first meaningful action?
- Where do they stop moving or look confused?
- Do they understand why a rarer robot matters?
- Do they notice their factory improving?
- Do they voluntarily continue after the first upgrade?
- Do they understand what a paid upgrade would do without needing sales copy?

## Phase 3 — Small public test

Publish with a deliberately limited content set and measure actual cohorts before buying meaningful traffic.

### Metrics to watch first

Per Roblox's analytics guidance, prioritize:

1. D1 retention;
2. average session time / playtime;
3. first-play bounce;
4. play-through rate;
5. D7 retention;
6. qualified sessions / repeat play;
7. payer conversion;
8. ARPPU / ARPDAU;
9. spend days per user;
10. intentional co-play.

Sources:
- https://create.roblox.com/docs/production/analytics
- https://create.roblox.com/docs/discovery

### Benchmarking rule

Do not invent a universal "good" retention or monetization number. When Creator Analytics provides similar-experience benchmark bands, compare the game against those 50th-90th percentile ranges.

Roblox exposes similar-game benchmarks for retention, average session time, ARPPU, ARPDAU, conversion rate, and play-through rate once enough data is available.

Source: https://create.roblox.com/docs/production/analytics/analytics-dashboard

## Phase 4 — Monetization experiment

Monetization should be built in from the start, but offers should be tuned using data.

Initial offer families:

### Permanent
- production multiplier;
- processor/assembler speed;
- extra work slot;
- storage convenience;
- auto-collect;
- VIP utility + cosmetics.

### Repeatable
- temporary production boost;
- guaranteed materials;
- instant process token;
- direct guaranteed event bundle;
- server-wide boost.

### Later
- subscription;
- rewarded video after eligibility;
- regional/managed pricing;
- Roblox price optimization only after transaction volume is sufficient.

Track per-offer:

- impressions / shop views;
- purchase prompts;
- completed purchases;
- purchaser progression stage;
- repeat purchase rate;
- retention difference between purchasers/non-purchasers;
- whether an offer causes players to quit after seeing it.

## Phase 5 — Acquisition test

Do not scale advertising until the game is competitive on retention and monetization with similar experiences.

When ready:

- test multiple icons/thumbnails;
- include an accurate gameplay video;
- keep title immediately descriptive;
- use small paid-acquisition tests first;
- compare acquisition cost against revenue/retention rather than celebrating visits alone.

Roblox states that gameplay videos on Home tests improved play quality/playtime and that Home recommendations depend on user behavior after discovery.

Sources:
- https://devforum.roblox.com/t/how-we-are-improving-home-this-year/4502571
- https://create.roblox.com/docs/discovery

## Go / pivot rules

### Continue building if

- players understand the game with minimal explanation;
- first-session funnel does not show a major early cliff we cannot cheaply fix;
- similar-experience retention/session benchmarks are reachable or improving;
- players show voluntary interest in collection/base progression;
- monetization offers map to real player bottlenecks rather than arbitrary paywalls;
- new content can be produced cheaply using existing systems.

### Pivot the loop if

- the game requires explanation to become fun;
- the reveal/collection layer does not create anticipation;
- upgrades mainly change numbers rather than the visible experience;
- players reach the perceived end too quickly;
- the only way to improve revenue is making free progression unpleasant.

### Kill/reuse the prototype if

After reasonable onboarding and balance iterations, player behavior still shows weak repeat interest relative to similar-experience benchmarks. In that case, preserve reusable systems (data, monetization, UI shell, factory framework, content pipeline) and test a new theme/loop rather than spending months forcing the original idea.

## Live-ops validation

Once the base loop works, updates should test one meaningful variable at a time when possible:

- new zone;
- new robot family;
- event cadence;
- collection rewards;
- production balance;
- offer placement;
- notification timing;
- co-op event structure.

Roblox Experiments can measure D1, D7, playtime, ARPU, ARPPU, conversion, and session time for controlled variants.

Source: https://create.roblox.com/docs/production/experiments

## Retention tools to add after the core loop proves itself

- daily/weekly goals;
- offline production claim;
- rotating guaranteed objectives;
- personalized experience notifications for eligible opted-in 13+ users;
- experience events/update announcements;
- friend invites / co-play rewards that do not require spending;
- collection milestones.

Sources:
- https://create.roblox.com/docs/production/promotion/experience-notifications
- https://create.roblox.com/docs/production/promotion/experience-events

## Final rule

**We optimize the business by learning quickly, not by maximizing launch scope.**

The first public version exists to prove: click -> understand -> enjoy -> progress -> return -> optionally spend.
