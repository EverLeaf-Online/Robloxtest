# Grow a Tiny Planet

A complete Roblox/Luau implementation of **Grow a Tiny Planet**. Each player owns an independently saved physical planet made from a sphere plus 144 spherical surface tiles. Water, plants, animals, settlements, cosmetics, a moon companion, milestones, Energy, purchases, and saves are all server-authoritative.

## Gameplay

- Start with **100 Energy**.
- Regenerate **+1 Energy every 5 seconds**. Fast Growth halves the interval.
- **Add Water** — 50 Energy. Converts a land surface tile into water.
- **Add Plants** — 75 Energy. Converts land into plants. Rare Seed charges create glowing rare plants.
- **Add Animals** — 100 Energy. Unlocks at 10 developed tiles. Fish require at least 3 water tiles; land animals require at least 5 plant tiles.
- **Build Settlement** — 200 Energy. Unlocks at 25 developed tiles and requires a connected cluster of at least 5 developed tiles with plant land available.
- **Terraform Burst** — 350 Energy. Unlocks at 50 developed tiles and develops up to 3 land tiles at once.
- Milestones: **10 / 25 / 50 developed tiles**.

## Controls

- **Left mouse + drag**: orbit the camera around your planet.
- **Mouse wheel**: zoom in/out.
- **Click without dragging**: select a surface tile for targeted actions.
- **B**: open/close the Cosmic Shop.

## Repository / Roblox Explorer Mapping

Rojo maps these files directly into Roblox Studio:

```text
ReplicatedFirst
└── Remotes
    ├── ApplyAction              RemoteEvent
    ├── UpdateEnergy             RemoteEvent
    ├── UpdateTile               RemoteEvent
    ├── MilestoneReached         RemoteEvent
    ├── PurchaseConfirmed        RemoteEvent
    ├── StateUpdated             RemoteEvent
    ├── Notify                   RemoteEvent
    └── GetPlanetState           RemoteFunction

ReplicatedStorage
└── Shared
    ├── Config                   ModuleScript
    └── TileGeometry             ModuleScript

ServerScriptService
├── ActionRouter                 Script
├── AnimalSystem                 ModuleScript
├── DataService                  ModuleScript
├── DataStore                    Script
├── EnergySystem                 ModuleScript
├── MilestoneSystem              ModuleScript
├── Monetization                 Script
├── MonetizationService          ModuleScript
├── PlanetAnimator               Script
├── PlanetRenderer               ModuleScript
├── PlanetStateService           ModuleScript
├── PlantSystem                  ModuleScript
├── PlayerManager                Script
├── SettlementSystem             ModuleScript
├── TerraformSystem              ModuleScript
└── WaterSystem                  ModuleScript

StarterPlayer
└── StarterPlayerScripts
    ├── CameraControls           LocalScript
    └── ClientWorld              LocalScript

StarterGui
└── MainUI                       LocalScript
```

Roblox does not have a service named `ClientScriptService`; client runtime code belongs in `StarterPlayerScripts` and `StarterGui`, which this project uses.

## Exact Setup Guide

### Option A — Rojo (recommended)

1. Clone this repository.
2. Install Rojo and the Roblox Studio Rojo plugin.
3. From the repository root run:

   ```bash
   rojo serve
   ```

4. Open a new Roblox Studio place.
5. Connect the Rojo Studio plugin to the running server and sync `default.project.json`.
6. Confirm the Explorer hierarchy matches the mapping above.
7. Publish the place to Roblox before testing DataStores or Marketplace purchases.

### Option B — Manual Studio copy

1. Create the Explorer folders and RemoteEvents/RemoteFunction exactly as shown above.
2. For every `.lua` file in `src/ReplicatedStorage/Shared` and `src/ServerScriptService` without `.server.lua`, create a **ModuleScript** with the same name and paste its source.
3. For every `.server.lua`, create a normal **Script** in `ServerScriptService`.
4. For every `.client.lua`, create a **LocalScript** in the Explorer location shown above.
5. Copy the complete source from the matching repository file.

## DataStore Testing

The game saves after every successful player action, on a 60-second autosave loop, when the player leaves, and during server shutdown.

1. Publish the experience.
2. In Studio open **Game Settings → Security**.
3. Enable **Studio Access to API Services** for DataStore testing.
4. Test once, change the planet, stop, then start again and verify that Energy, tiles, animals, settlements, milestone state, rare-seed charges, and purchase receipts restore.

The data layer uses two DataStores:

- `GrowATinyPlanet_PlayerData_v1`
- `GrowATinyPlanet_PlayerData_Backup_v1`

Every state mutation increments a revision. On load, the game checks both stores and uses the newest revision. Saves use `UpdateAsync` with retries so an older asynchronous save cannot overwrite newer state.

## Monetization Setup

Roblox asset IDs are experience-specific and cannot be safely invented. All Marketplace code is already implemented; only the IDs created in your Creator Dashboard must be inserted into:

`src/ReplicatedStorage/Shared/Config.lua`

Create these **Game Passes** and set their IDs:

| Config key | Roblox name | Price | Effect |
|---|---|---:|---|
| `FastGrowth` | Fast Growth | 299 R$ | 2× Energy regeneration speed |
| `CosmicSkin` | Cosmic Skin | 499 R$ | Unique cosmic planet surface pattern |
| `StarterPlanet` | Starter Planet | 999 R$ | One-time 5 water + 5 plant starting development |
| `MoonCompanion` | Moon Companion | 799 R$ | Physical moon orbiting the planet |

Create these **Developer Products** and set their IDs:

| Config key | Roblox name | Price | Effect |
|---|---|---:|---|
| `EnergyBoost` | Energy Boost | 49 R$ | +500 Energy |
| `RareSeedPack` | Rare Seed Pack | 99 R$ | +3 rare glowing plant charges |
| `CometStrike` | Comet Strike | 199 R$ | Develops up to 3 random land tiles |

Leave no ID at `0` for production. `0` deliberately prevents invalid Marketplace prompts while developing before the assets exist.

`MarketplaceService.ProcessReceipt` is assigned in exactly one place: `ServerScriptService/Monetization.server.lua`. Developer-product receipt IDs are persisted to prevent duplicate grants, and Roblox is only told `PurchaseGranted` after the state has successfully reached a DataStore.

## Multiplayer / Security Model

- The client sends only `{ actionType, tileIndex }`.
- Energy, tile state, habitat eligibility, settlement clustering, milestones, unlocks, and costs are validated on the server.
- Global minimum action interval is 1 second.
- Terraform Burst has a 15-second action-specific cooldown.
- Invalid/NaN/out-of-range tile indices are rejected.
- Each player receives a separate planet model in `Workspace/Planets` at a separate world slot.
- The camera automatically focuses only on the local player's planet.
- Player characters are parked invisibly away from the planet because gameplay uses the orbit camera rather than an avatar controller.

## Multiplayer Test Checklist

Use Studio **Test → Start** with at least 2 players and verify:

1. Both clients focus different planets.
2. Water/plant actions on Player 1 do not change Player 2's planet.
3. Energy costs and regeneration are server driven.
4. Clicking a surface tile targets it; dragging rotates instead.
5. Animals reject until the 10-tile milestone and habitat requirement are met.
6. Settlements reject until the 25-tile unlock and a 5-tile connected developed cluster exist.
7. Terraform Burst unlocks at 50 developed tiles.
8. Repeated remote spam faster than the cooldown is rejected.
9. Leaving/rejoining restores the planet.
10. With real Marketplace IDs configured, pass purchases update the current planet without replacing the camera target, and developer products grant exactly once per receipt.

## Main Source Files

- `src/ServerScriptService/PlayerManager.server.lua` — join/leave lifecycle.
- `src/ServerScriptService/ActionRouter.server.lua` — RemoteEvent validation, anti-exploit checks, cooldowns, action dispatch, action saves.
- `src/ServerScriptService/PlanetRenderer.lua` — sphere, 144 physical surface tiles, animals, settlements, cosmic styling, moon.
- `src/ServerScriptService/DataService.lua` — primary/backup `UpdateAsync`, retry logic, sanitation, newest-revision recovery.
- `src/ServerScriptService/DataStore.server.lua` — autosave and shutdown save.
- `src/ServerScriptService/MonetizationService.lua` — pass ownership, pass effects, developer-product receipts.
- `src/StarterPlayer/StarterPlayerScripts/CameraControls.client.lua` — smooth orbit/zoom camera.
- `src/StarterPlayer/StarterPlayerScripts/ClientWorld.client.lua` — procedural starfield and space lighting.
- `src/StarterGui/MainUI.client.lua` — Energy HUD, action buttons, stats, tile targeting, shop, milestones, notifications.

No free models are required. Animals, settlements, surface tiles, moon, stars, and cosmetic visuals are built procedurally from Roblox instances.
