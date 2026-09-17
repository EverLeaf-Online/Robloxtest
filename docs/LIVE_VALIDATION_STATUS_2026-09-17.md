# Scrap-to-Bot Factory — Live Validation Status

Status date: **2026-09-17**  
Source branch: `main`  
Post-merge hardening head: `1b78f70b9b48179bc53329329f0e4bed5fcf5767`

This is the current authoritative execution status for the monetization/engagement validation pass. It supersedes the older runtime assumptions in `FIRST_PLAYABLE_STATUS_2026-09-16.md` where they conflict.

## Published test experience

- Experience/universe ID: `10766713640`
- Current published test experience name: `Scrap-to-Bot Factory - Tests`
- Current access during validation: Private
- Rojo/Git source branch: `main`

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

## Studio monetization validation — verified

Verified in Roblox Studio using both the dedicated Studio test harness and Roblox Marketplace test-purchase prompts where applicable:

- 2x Production grants the expected exact production multiplier.
- Expanded Storage applies correctly.
- Auto-Collect entitlement applies correctly.
- +2 Bot Work Slots allows three total work slots from the one-slot baseline without requiring an in-game slot upgrade.
- Factory VIP nameplate presentation works.
- Factory VIP assembler-speed benefit works.
- Instant Process Tokens can be consumed repeatedly against valid jobs.
- Factory Club Studio activation uses the same grant/state path as the live subscription refresh path.
- Factory Club monthly test bundle grants materials and tokens.
- Factory Club collectible cosmetic ownership/equip presentation works.
- Factory Club storage convenience multiplier applies.
- Live shop UI prompts the configured Developer Products and subscription.
- Shop product prices resolve dynamically through MarketplaceService rather than being hard-coded into grant logic.

## Receipt processing — verified in Studio

The developer-product receipt path is server authoritative through `MarketplaceService.ProcessReceipt` / the shared `processReceipt` implementation.

Verified behavior:

- Material Supply Crate grants the exact configured paid material bundle.
- 15-Minute Factory Overclock adds 15 minutes to the current personal-overclock expiry.
- Re-buying the personal overclock adds another 15 minutes rather than resetting the timer.
- Server Overclock adds 15 minutes to the current server-overclock expiry.
- Re-buying Server Overclock adds another 15 minutes rather than resetting the timer.
- A successfully granted Studio-simulated receipt can be replayed and returns `PurchaseGranted` without granting value again.
- A successfully granted Roblox Studio Marketplace test-purchase receipt is captured by the Studio harness and can be replayed through the same idempotency check.
- Replay does not extend personal or server overclock timers.
- Failed/ungranted Studio receipts are not stored as replay candidates.
- Receipt history is bounded and duplicate PurchaseIds are checked before any grant.
- Paid material grants use paid-cap handling rather than normal storage-cap rejection while still respecting the absolute material hard cap.
- Receipt rewards are saved before successful acknowledgement.

Studio replay status confirmed in UI:

- `ReplayLastReceipt: PASS (RECEIPT_REPLAY_IDEMPOTENT)`

## Live persistence/reconnect — verified

Verified in the published Roblox client:

- Credits persist across leave/rejoin.
- Materials persist across leave/rejoin.
- Owned robots persist across leave/rejoin.
- Robot work-pad assignments persist across leave/rejoin.
- Upgrades persist across leave/rejoin.
- Zone progression persists across leave/rejoin.
- General saved progression restores correctly through a real published-session reconnect.

Not yet live-verified because the test account has no Robux to activate them in production:

- personal-overclock persistence after a real Robux purchase;
- real Developer Product receipt fulfillment with an actually charged Robux transaction;
- real Factory Club subscription refresh/grant state with an actually subscribed account.

These remain explicitly **untested live**, not failed.

## Notification opt-in — verified live

The published Roblox client executed the opt-in controller and logged:

- `WAITING_FOR_DELAY`
- `CHECKING_ELIGIBILITY`
- `PROMPT_UNAVAILABLE`

Roblox account settings were then inspected and confirmed:

- the test experience appears under **My Games — Games with enabled notifications**;
- its notification toggle is enabled;
- Roblox game-event desktop/mobile notification settings are enabled for the account.

Therefore the live opt-in code path is working and the account is already in an enabled notification state. `PROMPT_UNAVAILABLE` is not treated as an error because Roblox does not expose a more specific reason when `CanPromptOptInAsync()` returns false.

## Engagement hardening merged

Post-merge hardening is now on `main` through PR #4.

Implemented:

- duplicate badge-award noise is avoided by checking `UserHasBadgeAsync` before attempting `AwardBadgeAsync`;
- `FactoryClubRewardGranted` is wired to the configured `FactoryClubReward` experience notification;
- `RequestAdminBroadcast` now has a server-authoritative creator check and cannot be used by ordinary clients;
- creator-entered NewContent text is normalized, bounded to 120 UTF-8 characters, and filtered before live publication;
- NewContent announcements publish through `MessagingService` for active servers;
- active players receive an in-game announcement plus the configured `NewContent` notification send attempt;
- broadcast deduplication is bounded to 100 message IDs per server;
- the client renders the existing `Announcement` remote, which also makes referral reward announcements visible;
- a creator-only client panel drives the existing rate-limited admin broadcast remote while the server remains authoritative.

Validation on the hardening PR:

- GitHub CI passed, including Wally lock validation, StyLua, Selene, shipping Rojo build, and test Rojo build;
- the OCALE no-publish Luau execution probe passed;
- the Jest runtime workflow still stopped at the place-publish step under the existing dedicated-test-place edit-lock condition, so this is not treated as a code regression.

NewContent delivery is still **not marked live-verified** until a real cross-server published-session test is run. The current implementation targets active servers/players; it is not an offline full-audience campaign system.

## FactoryReady notification delivery — blocked for now

Implementation status:

- FactoryReady scheduling exists.
- Durable queue/lock stores exist.
- server-side Open Cloud notification sender is wired.
- official Open Cloud `UserNotification` package source is vendored under Git/Rojo control.
- client opt-in state is confirmed enabled.

Live delivery is **not yet marked verified**.

Current blocker for meaningful production delivery validation: Roblox experience-notification eligibility requires the experience to reach the platform visit threshold before personalized delivery can be relied on for testing. Re-test FactoryReady after the experience reaches **100 visits**.

A temporary two-minute FactoryReady delay was used only for diagnosis and has already been reverted. Production config is back to:

- `FactoryReadyDelaySeconds = 30 * 60`

Also note an architecture reliability limitation: the current FactoryReady queue is polled by active Roblox game servers. If the last player leaves and the server shuts down, a queued notification may have no active game server available to process it later. An always-on external Open Cloud worker is a possible future hardening step, but it is not required to close the current 100-visit eligibility blocker.

## Live tests still pending

Pending because they require Robux, platform eligibility, or a real multi-server published test:

- actual charged Developer Product purchase in the published experience;
- actual Factory Club subscription state and monthly reward in production;
- personal overclock live persistence after a real purchase;
- FactoryReady push delivery after the experience reaches 100 visits;
- ReferralReward push delivery under real referral qualification;
- FactoryClubReward push delivery under a real subscription billing cycle;
- NewContent cross-server announcement/notification delivery validation.

## Current known housekeeping

- Duplicate badge-award warnings have been addressed in code; re-check published server output after the next publish.
- Server Overclock is intentionally server-session state, not player-profile persistence. A new server is not expected to inherit the previous server's timer under the current design.
- FactoryReady production delay has been restored to 30 minutes after the temporary test.
- The dedicated OCALE test place must release its edit lock before the full Jest runtime workflow can publish its temporary test build.

## Current completion state

### Verified enough to move on

- core persistence/reconnect path;
- Studio pass behavior;
- Studio Developer Product grant behavior;
- receipt retry/idempotency behavior;
- repeat overclock purchase extension behavior;
- Studio/live-shop prompt wiring;
- Factory Club Studio grant/presentation path;
- live notification opt-in/eligibility controller path;
- notification settings enabled for the test experience;
- static/build validation for post-merge engagement hardening;
- OCALE no-publish Luau execution probe.

### Come back later

- charged Robux receipt test;
- real subscription test;
- FactoryReady delivery after 100 visits;
- ReferralReward/FactoryClubReward live delivery;
- NewContent cross-server live delivery;
- full OCALE Jest execution after the dedicated place edit lock releases.

Do not mark those later items failed simply because they are currently blocked by test-account funds, Roblox eligibility, or the external test-place edit lock.
