# Scrap-to-Bot Factory — Roblox Monetization IDs

Status: **Active test-experience configuration**  
Last updated: **2026-09-16**

These IDs belong to the dedicated Roblox test experience for **Scrap-to-Bot Factory - Tests**.

## Experience

- Experience / Universe ID: `10766713640`

## Developer Products

| Product | Product ID | Base Price |
|---|---:|---:|
| Material Supply Crate | `3713191213` | 49 R$ |
| 15-Minute Factory Overclock | `3713191406` | 39 R$ |
| Instant Process Tokens | `3713191584` | 25 R$ |
| Starter Pack | `3713191832` | 79 R$ |
| Server Overclock | `3713191857` | 99 R$ |

## Passes

| Pass | Pass ID | Base Price |
|---|---:|---:|
| 2x Production | `1982138683` | 299 R$ |
| Expanded Storage | `1985786272` | 149 R$ |
| +2 Bot Work Slots | `1985060498` | 249 R$ |
| Auto-Collect | `1982138684` | 299 R$ |
| Factory VIP | `1982714688` | 499 R$ |

## Implementation rules

- Do not reuse these IDs in another Roblox experience.
- Developer Products must be granted server-side through `MarketplaceService.ProcessReceipt`.
- Receipt handling must be idempotent so retries cannot duplicate grants.
- Pass ownership must be checked server-side; client entitlement state is presentation-only.
- Managed Pricing is enabled for the products and passes listed above.
- No paid randomized robot rolls are part of the launch plan.
- The Starter Pack is presented as a starter offer, but any successfully purchased receipt must still grant its advertised value.

When implementation begins, these IDs should be mirrored into the server/shared monetization configuration rather than duplicated ad hoc across scripts.
