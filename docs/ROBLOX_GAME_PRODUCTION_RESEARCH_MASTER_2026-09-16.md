# Roblox Game Production Research Master

Research baseline: 2026-09-16

This document corrects the earlier research mistake of focusing too narrowly on "what kind of Roblox game is trending." Market demand matters, but it is only one layer. Before production gameplay begins, this project must understand the current Roblox platform as an engineering, product, operations, monetization, security, UX, analytics, and publishing system.

## 1. Product / game design

Research areas:
- platform-specific Roblox player behavior;
- core loop design;
- FTUE / onboarding;
- progression pacing;
- quests, dailies, achievements, prestige/rebirth;
- social motivators and co-play;
- retention loops;
- LiveOps cadence;
- update architecture;
- content scalability;
- genre norms and player expectations.

Current implementation implications:
- the premise must be understandable in seconds;
- first useful interaction begins almost immediately;
- tutorials should be contextual and visual, not a long instruction wall;
- early progression thresholds should be deliberately low enough to demonstrate growth quickly;
- the first session should expose the complete core loop, not just one isolated mechanic;
- the player should always see a short-term and medium-term goal;
- progression must generate visible world/character/factory change;
- social design should create reasons to play near or with other users without making solo play nonviable;
- systems should be designed so weekly/monthly content can extend existing mechanics rather than require entirely new technology each update.

Primary official references:
- Creator Hub game design overview
- Design for Roblox
- Core loops
- Onboarding
- Onboarding techniques
- LiveOps essentials

## 2. Architecture / code organization

Research areas:
- Luau project organization;
- Rojo-based source workflow;
- dependency management;
- explicit server services and client controllers;
- shared config/schema modules;
- dependency minimization;
- tags/attributes and data-model organization;
- loading/replication assumptions;
- streaming-aware code.

Current implementation implications:
- no Knit foundation for a new 2026 project because Knit is archived;
- prefer small explicit services over a monolithic framework;
- use Rojo for source-controlled Luau;
- use Rokit rather than restoring the old archived Aftman workflow;
- use Wally only for reviewed dependencies we can replace/migrate away from;
- use CollectionService tags/Attributes where they improve authoring, but replicated attributes are never secret state;
- never assume replication order; use safe loading patterns and streaming-aware references;
- keep authoritative configs server-owned when they contain economy/security-sensitive values.

## 3. Networking / client-server boundary

Research areas:
- RemoteEvent / RemoteFunction usage;
- UnreliableRemoteEvent use cases;
- input validation;
- rate limiting;
- context/permission checks;
- replay/race handling;
- ProximityPrompt / ClickDetector / Touched security;
- network ownership and physics exploits;
- server authority roadmap.

Current implementation implications:
- clients request intent, never outcomes;
- every valuable client-triggered action is type/range/state/ownership/proximity/cooldown validated;
- no client-supplied price, reward, rarity, multiplier, production amount, sale value, prestige result, zone unlock, or inventory delta;
- ProximityPrompt, ClickDetector and Touched are treated as hostile client-triggerable surfaces just like remotes;
- critical unanchored physics cannot be trusted when client-owned;
- gameplay-critical economy state does not derive from client physics alone;
- RemoteFunctions are used sparingly because they yield and increase coupling;
- noncritical high-frequency visuals/state may later use UnreliableRemoteEvents after profiling.

## 4. Exploit / adversarial research

Research areas:
- remote spying and replay;
- client decompilation;
- closure/upvalue/constant inspection;
- client anti-cheat bypass;
- teleport/autofarm;
- hidden-object ESP;
- remote-key extraction;
- progression automation;
- network ownership abuse;
- race/disconnect transaction edges.

Current implementation implications:
- assume the attacker can inspect all replicated LocalScripts/ModuleScripts and all client->server remote traffic;
- assume local constants/upvalues/tokens can be read or changed;
- hidden remote names and client secrets are not security controls;
- a compromised client must still be unable to mint durable server-side value;
- anti-cheat is primarily authoritative validation + bounded throughput + anomaly telemetry, not executor detection.

Reference-only adversarial repositories currently reviewed:
- retpirato/Roblox-Scripts
- Stefanuk12/ROBLOX
- Upbolt/Hydroxide

## 5. Persistent data / economy integrity

Research areas:
- DataStoreService best practices;
- session locking;
- revision/version fields;
- schema migration;
- atomic updates;
- backups / data versions;
- save cadence;
- shutdown/leave handling;
- failure modes;
- Studio data isolation;
- operational repair/migration tooling;
- MemoryStore vs DataStore vs Configs vs Secrets Store.

Current implementation implications:
- use one or a few deterministic keys per player rather than many fragmented stores;
- buffer profile data in server memory and save periodically plus critical checkpoints;
- save related values atomically when they must remain consistent;
- maintain schema/version and migration code;
- protect players from destructive overwrite if cloud reads fail;
- use staging/test data rather than allowing Studio to casually touch production data;
- use MemoryStore only for ephemeral cross-server state;
- use Configs for live tunable read-only values/experiments where suitable;
- keep secrets in the platform Secrets Store rather than source/ReplicatedStorage;
- plan external data repair/migration through Open Cloud/Data Stores Batch Processor, not dangerous mass-edit admin remotes.

ProfileStore remains a strong candidate, but adoption must include a migration/exit plan so our player data is not trapped behind one library.

## 6. Economy design / balance

Research areas:
- sources/sinks;
- inflation control;
- upgrade curves;
- capacity bottlenecks;
- resource tiers;
- prestige resets;
- offline earnings;
- duplicate conversion/selling;
- event currency isolation;
- premium acceleration;
- economy analytics.

Current implementation implications:
- every currency and material has explicit sources and sinks;
- early progression is fast enough to demonstrate the loop, then expands into longer goals;
- premium acceleration should target recognizable bottlenecks rather than make baseline play intentionally miserable;
- offline income is bounded and server-calculated from timestamps;
- event economies should not accidentally inject uncontrolled value into the permanent economy;
- EconomyEvents instrument all meaningful resource sources/sinks from launch.

## 7. Monetization

Research areas:
- passes;
- repeatable developer products;
- subscriptions;
- Roblox Shop;
- managed/regional pricing;
- price optimization;
- rewarded video;
- Creator Rewards;
- contextual purchases;
- season-pass design;
- paid-random-item restrictions;
- PolicyService;
- refund/receipt implications;
- ethical shop design.

Current implementation implications:
- permanent boosts/convenience -> passes;
- repeatable materials/temporary boosts/instant completion/server boosts -> developer products;
- recurring convenience/cosmetics/content allowance -> subscription later;
- developer-product rewards are granted only from authoritative receipt processing;
- dynamic/platform pricing is displayed rather than hardcoded Robux text;
- no fake scarcity, fake countdowns, or misleading urgency;
- paid randomness is not a launch centerpiece; if ever introduced, disclose actual numerical odds and obey per-user PolicyService restrictions;
- rewarded-video rewards must be user-initiated and guaranteed, not paid-random outcomes;
- Creator Rewards are a secondary upside, not a reason to artificially waste player time.

## 8. Analytics / experimentation

Research areas:
- economy events;
- funnels;
- custom events;
- retention/playtime/session KPIs;
- play-through and bounce;
- co-play metrics;
- monetization KPIs;
- A/B experiments;
- config-driven tuning;
- similar-experience benchmark comparison.

Current implementation implications:
- AnalyticsService events originate on the server;
- launch instrumentation covers FTUE, the core loop, progression, shop exposure, purchase completion, zone unlock and prestige;
- economy analytics track sources, sinks and wallet balances;
- funnel analytics identify exact abandonment steps;
- experiments test onboarding, progression values, starter grants, shop placement and pricing rather than changing them by intuition;
- advertising spend follows product validation, not the other way around.

## 9. UI / UX / accessibility / input

Research areas:
- responsive/adaptive design;
- touch, mouse/keyboard, gamepad;
- active input switching;
- focus/navigation;
- visual hierarchy;
- readability;
- platform genre conventions;
- internationalization/localization;
- accessibility scaling;
- automated UI testing.

Current implementation implications:
- do not design desktop-first and shrink it for phones;
- core actions must work with touch, mouse/keyboard and gamepad;
- layouts react to screen size/orientation;
- important buttons stay inside comfortable touch zones;
- UI uses strong visual communication and limited text where possible;
- every core flow must remain navigable with gamepad focus;
- UI text is localization-friendly;
- React Luau is the current leading UI candidate, with Fusion/plain UI still valid depending on prototype cost;
- Jest Roblox + React Testing Library Lua are candidates for regression tests around onboarding/shop/upgrade flows.

## 10. Performance / streaming / memory

Research areas:
- client frame time;
- server heartbeat;
- memory;
- join time;
- instance streaming;
- texture resolution;
- asset duplication;
- audio memory;
- task scheduler;
- render-step misuse;
- physical simulation cost;
- MicroProfiler workflow.

Current implementation implications:
- design for lower-end mobile from the start;
- target smooth 60 FPS behavior while accepting that device capability varies;
- world architecture must support Instance Streaming before it becomes large;
- avoid unnecessary Persistent streaming models;
- reuse assets/materials/textures instead of creating redundant unique uploads;
- use texture resolution appropriate to actual on-screen size;
- do not preload the entire game's audio/content blindly;
- avoid per-frame Luau work unless it is genuinely frame-critical;
- profile rather than guessing when deciding whether networking/physics optimizations are needed.

## 11. Testing / QA

Research areas:
- unit tests;
- integration tests;
- scripted multi-client tests;
- simulated input;
- device/orientation tests;
- join/leave stress;
- disconnect/save edges;
- purchase receipt idempotency;
- exploit-shaped request tests;
- staging publishing.

Current implementation implications:
- Jest Roblox is the preferred modern test framework candidate;
- StudioTestService can programmatically start a server with up to eight simulated clients and exercise joins/disconnects;
- VirtualInput can drive UI/input tests;
- device simulation must be part of the normal QA matrix;
- economy remotes require hostile-input test cases, not just happy-path tests;
- receipts must be tested for repeats/retries/disconnects;
- production publish is gated on automated checks + manual gameplay smoke test.

## 12. Assets / world-building pipeline

Research areas:
- original asset production;
- Blender -> Studio import;
- FBX/glTF workflow;
- PBR/textures;
- mesh/texture memory budgets;
- reusable packages;
- asset permissions;
- Creator Store safety;
- audio licensing;
- modular environment production.

Current implementation implications:
- use original or clearly licensed assets only;
- packages are preferred for reusable world/factory/bot modules because they support versioning/update propagation;
- imported third-party models are inspected for malicious scripts;
- modular bot/factory construction lowers content-production cost;
- ownership must be chosen correctly when uploading assets/packages because asset ownership transfers are limited;
- licensed Creator Store audio or original audio only.

## 13. Publishing / deployment / operations

Research areas:
- Private / Limited / Public audiences;
- content maturity/compliance;
- staging universe/place separation;
- place publishing API;
- GitHub CI/CD;
- Open Cloud API keys/OAuth;
- rollback/version verification;
- data repair tools;
- webhooks;
- operational dashboards/alerts.

Current implementation implications:
- build/test in Limited or private/staging workflow before public launch;
- production data is isolated from local/Studio testing;
- Open Cloud Place Publishing can later deploy tested place builds from CI;
- API keys/secrets never enter the repo;
- publish automation must account for place-publishing limitations on certain asset instance types;
- live data changes/migrations use explicit audited tools rather than ad-hoc in-game commands.

## 14. Safety / policy / moderation

Research areas:
- PolicyService;
- text filtering;
- TextChatService;
- UGC/user-entered names;
- age/location restrictions;
- advertising eligibility;
- paid-item trading restrictions;
- content maturity;
- IP/licensing.

Current implementation implications:
- all user-visible user-generated text is filtered;
- chat uses supported TextChatService paths;
- any future pet/bot naming is filtered before display to other users;
- PolicyService gates region/age/platform-sensitive monetization features;
- third-party game archives are design references only unless actual reuse rights are verified;
- no copied game maps/UI/assets/brands/franchise IP.

## 15. Discovery / acquisition / packaging

Research areas:
- Recommended For You signals;
- play-through;
- bounce;
- D1/D7/D28 repeat play;
- playtime/session quality;
- social/co-play;
- spending signals;
- icon/thumbnail/video packaging;
- Search Ads / Ads Manager;
- acquisition testing.

Current implementation implications:
- gameplay itself must create strong short clips and thumbnails;
- thumbnails/videos accurately represent real gameplay;
- packaging communicates the main verb and reward immediately;
- paid acquisition is tested with small budgets only after FTUE/core-loop metrics are credible;
- different creatives can be tested independently from game changes.

## 16. Current concept research implication

The market pass currently favors an incremental/simulation/collection game, with **Scrap-to-Bot Factory** as the leading concept. That conclusion is not enough to greenlight production by itself.

The concept must still satisfy all production constraints above:
- server-authoritative collectible/economy pipeline;
- deterministic persistent profile schema;
- mobile-first interaction;
- modular asset budget;
- analytics from first playable;
- visible first-session progression;
- scalable content pipeline;
- clear monetization surfaces;
- low exploit value per client action;
- testable update/deployment pipeline.

## 17. Research gates before gameplay implementation

Production gameplay should not start until these deliverables exist:

1. Locked one-sentence product pitch and target audience.
2. Core loop diagram and first 30-minute progression table.
3. Currency/material source-sink table.
4. Upgrade formulas and first prestige hypothesis.
5. Player data schema + migration/session-lock strategy.
6. Remote/action contract list with validation rules.
7. Monetization surface map and placeholder config IDs.
8. FTUE funnel event plan.
9. Mobile/desktop/gamepad UI wireframe requirements.
10. World/asset modularity and performance budget.
11. Automated/manual test matrix.
12. Staging -> production publishing workflow.
13. LiveOps/update content template.
14. Security abuse-case checklist for every economy action.
15. Legal/provenance rule for every imported asset/dependency.

## 18. What still needs deeper research

The following are not considered solved merely because this document exists:
- detailed first-30-minute economy curve using comparable simulator pacing;
- concrete device/performance budget for target phones;
- UI visual reference teardown of current successful simulators;
- exact modular bot art pipeline and production cost;
- current Creator Store asset candidates and their licenses/permissions;
- detailed social loop and server population target;
- exact LiveOps cadence sustainable for a one/small-person team;
- player-data library prototype comparison (ProfileStore vs minimal in-house wrapper);
- React Luau vs Fusion prototype cost/performance comparison;
- automated Roblox cloud test/publish proof-of-concept;
- controlled closed-playtest methodology before acquisition spend.

Those must be answered proactively rather than waiting for the user to send another repository or documentation link.

## Source hierarchy

1. Current Roblox Creator Hub / official API/policy docs.
2. Roblox creator-docs source repository.
3. Maintained official Roblox/Luau repositories.
4. Roblox staff announcements.
5. Our own analytics/experiments.
6. Maintained reviewed OSS with compatible licenses.
7. Current competitor/market research.
8. Community discussion.
9. Historical/exploit/uncopylocked sources only as adversarial/design references.

## Bottom line

"Research" for this project means understanding the complete production system required to ship, operate, secure, monetize, measure, update, and grow a Roblox game—not merely identifying which genre is currently popular.
