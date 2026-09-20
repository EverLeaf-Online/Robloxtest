# Scrap-to-Bot Factory — Roblox Creator Dashboard Configuration

Status: **Active test-experience configuration**  
Last reconciled: **2026-09-17**

This document preserves the useful Creator Dashboard configuration that previously existed only on the parallel implementation branch. Runtime/release verification belongs in `docs/ROADMAP.md`; this file is configuration/reference only.

## Experience identity

- Experience name: `Scrap-to-Bot Factory - Tests`
- Experience / Universe ID: `10766713640`
- Genre: `Simulation`
- Subgenre: `Tycoon`
- Audience: `Limited`
- Content maturity: `Minimal`
- Age restriction: none
- Payment: free to play
- Maximum visitor count: `8`

The experience remains Limited until launch-readiness testing is complete.

## Platforms and access

- Desktop: enabled
- Mobile: enabled
- Tablet: enabled
- Console: enabled
- VR: disabled
- Place access: fully open within the Limited experience
- Private servers: disabled for the current test phase
- Place copying: disabled
- Create Place API: disabled
- Save Place API: disabled

## API / data configuration

- Studio access to API services: enabled for the dedicated test experience
- Mesh / Image APIs: disabled unless deliberately needed later
- Profile key format: `Player_{UserId}`
- Production persistence is session-locked and server-authoritative.
- RTBF deletion configuration remains an operations task to review against the final persistent-key inventory before public launch.

## Communication

- Cross-server chat: disabled
- Strong Language: disabled
- NewContent cross-server announcements are game-controlled through `MessagingService`; this is separate from cross-server player chat.

## Discovery media

- Custom square game icon: uploaded
- Three discovery thumbnails: uploaded and active
- Thumbnail personalization: enabled
- Gameplay video: intentionally deferred until representative polished gameplay exists

Do not upload simulated/fake gameplay footage as representative gameplay.

## Monetization

The canonical human-readable product/pass/subscription ID table is `docs/ROBLOX_MONETIZATION_IDS.md`. Runtime IDs are in `src/shared/Config/RobloxIds.lua`.

Configured categories include five Developer Products, five Passes, and the Factory Club monthly subscription. Managed Pricing is enabled for products/passes and Regional Pricing is enabled for Factory Club.

No paid randomized robot roll is part of the launch plan.

## Badges

Five launch badges are configured and active. See `docs/ROBLOX_BADGE_IDS.md` for IDs, award purpose, and display order.

Awards are server-authoritative through `BadgeService`.

## Notifications

Configured notification string asset IDs:

| Name | Asset ID |
|---|---|
| `FactoryReady` | `3e45ef59-0f23-ee44-9365-5c4402e5e3cd` |
| `ReferralReward` | `806403da-e0cf-494e-9cb7-974fab0ff1a4` |
| `FactoryClubReward` | `9de31ecb-88a8-4645-843a-b90c1952419d` |
| `NewContent` | `e1abb235-8da6-814a-a388-a99aefb23213` |

Delivery eligibility and current validation limitations are tracked in `docs/ROADMAP.md`.

## Referral configuration

- Dashboard reward name: `Bring a Friend`
- Expiration configured: `2026-12-31`
- Inviter reward cap implemented in game: 5 qualified rewards
- Qualification/reward logic is server-authoritative.

## Localization / safety / ads

- Source language: English
- Additional localization: deferred
- Rewarded Video: off
- Safety/Moderation pages: reviewed for the test experience
- Add collaborators only when needed and use least privilege

## Remaining dashboard operations

- Add the dedicated Scrap-to-Bot social/Discord link when ready for external players.
- Add a real gameplay video only after polished representative gameplay exists.
- Finalize RTBF deletion handling against the final profile-key inventory.
- Configure operational alerts/monitoring once live signals justify them.
- Build analytics dashboards once enough real traffic exists.
- Revisit ads/localization only after the core loop and economy are validated.
- Review thumbnail performance only after statistically meaningful traffic exists.
- Change Audience from Limited to Public only after explicit launch approval.

## Source-of-truth rule

When this configuration record disagrees with runtime code or a newer live-validation record:

1. `src/shared/Config/RobloxIds.lua` is authoritative for IDs used by code.
2. `docs/ROADMAP.md` is authoritative for current runtime-validation and release status.
3. This document records Creator Dashboard configuration and should be updated when dashboard settings change.
