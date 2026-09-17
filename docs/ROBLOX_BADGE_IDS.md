# Scrap-to-Bot Factory — Roblox Badge IDs

Status: **Active test-experience configuration**  
Last updated: **2026-09-17**

These badge IDs belong to the Roblox test experience **Scrap-to-Bot Factory - Tests** (`10766713640`).

| Badge | Badge ID | Purpose |
|---|---:|---|
| First Scrap | `3252417673375380` | Collect your first piece of salvage. |
| First Bot Built | `1761109998097830` | Assemble your first robot. |
| Factory Online | `2465984964619301` | Assign your first robot and begin automated production. |
| Rare Discovery | `2071285833691013` | Build or discover your first Rare-or-better bot. |
| Zone Two Unlocked | `1290904645327424` | Unlock the second salvage zone. |

## Display order

1. First Scrap
2. First Bot Built
3. Factory Online
4. Rare Discovery
5. Zone Two Unlocked

## Implementation rules

- Award badges server-side only.
- Treat badge checks/awards as idempotent; retries must not create side effects.
- Do not trust the client to report progression milestones.
- Badge conditions are derived from authoritative server progression state.

Runtime IDs are mirrored in `src/shared/Config/RobloxIds.lua`. See `docs/LIVE_VALIDATION_STATUS_2026-09-17.md` for current runtime validation status.
