# Grow a Tiny Planet

**Grow a Tiny Planet** is a server-authoritative Roblox planet-growth game built in Luau. Every player owns a separately saved physical world made from a sphere and 144 spherical surface tiles. Water, vegetation, animals, settlements, rare growth, monetization benefits, milestones, Energy, and progression are persisted per player.

## Current playable loop

1. Start with **100 Energy**.
2. Click anywhere on the visible planet to inspect the nearest surface tile.
3. Add **Water** or **Plants** to exact land tiles, or choose a growth tool first and then click the planet.
4. Grow connected oceans and vegetation biomes.
5. Reach **10 developed tiles** to unlock animals and earn **+150 Energy**.
6. Build at least 3 water tiles for fish or 5 plant tiles for land animals.
7. Reach **25 developed tiles** to unlock settlements and earn **+350 Energy**.
8. Found settlements on planted tiles inside connected developed regions.
9. Reach **50 developed tiles** to unlock Terraform Burst and earn **+750 Energy**.
10. Continue through planet evolution stages toward a 100-tile **Garden World**.

Energy regenerates at **+1 every 5 seconds**. The Fast Growth pass halves that interval.

## Actions

| Action | Cost | Requirement | Result |
|---|---:|---|---|
| Add Water | 50 | Land tile | Creates physical blue water surface |
| Add Plants | 75 | Land tile | Creates vegetation; rare seed charges create glowing crystal growth |
| Add Animals | 100 | 10 developed tiles + valid habitat | Adds an animated fish or land animal |
| Build Settlement | 200 | 25 developed tiles + connected 5-tile developed cluster | Adds a physical settlement |
| Terraform Burst | 350 | 50 developed tiles | Develops up to 3 random land tiles |

Targeted actions are deterministic: if a selected tile is invalid, the server rejects the action instead of silently changing another tile.

## Controls

- **Click a planet tile** — select it and open the tile inspector.
- **Choose a growth tool, then click the planet** — apply that tool to the clicked tile.
- **1 / 2 / 3 / 4 / 5** — Water / Plants / Animals / Settlement / Terraform Burst.
- **R** — use the currently armed tool on a random valid tile.
- **Left mouse + drag** — orbit around the planet.
- **Mouse wheel** — zoom.
- **Touch drag** — orbit on touch devices.
- **Two-finger pinch** — zoom on touch devices.
- **B** — open/close the Cosmic Shop.
- **Escape** — clear target/tool selection.

Planet clicks use an analytic sphere fallback, so gaps between the 144 visible tile discs do not create dead click zones.

## Physical planet rendering

- 40-stud-radius spherical core.
- 144 server-created surface tiles using Fibonacci-sphere placement.
- Water uses glass-like blue tiles.
- Plant tiles grow miniature physical trees.
- Rare plant tiles grow glowing physical crystal clusters with local light.
- Settlements and animals are physical procedural models.
- Optional Moon Companion physically orbits the planet.
- A translucent atmosphere shell, key light, bloom, and procedural starfield provide the space scene.

No free models are required.

## Planet stages

The HUD derives a stage from developed surface count:

- 0: **Barren World**
- 5: **Young World**
- 10: **Living World**
- 25: **Settled World**
- 50: **Thriving World**
- 100: **Garden World**

## Explorer mapping

Rojo maps the project into Roblox Studio:

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
├── WaterSystem                  ModuleScript
└── WorldSetup                   Script

StarterPlayer
└── StarterPlayerScripts
    ├── CameraControls           LocalScript
    └── ClientWorld              LocalScript

StarterGui
└── MainUI                       LocalScript
```

Roblox does not have a `ClientScriptService`; client runtime scripts belong in `StarterPlayerScripts` and `StarterGui`.

## Rojo setup

This project can run on a dedicated Rojo port when another Roblox project is already using the default port:

```powershell
rojo serve --port 34873
```

Connect the Roblox Studio Rojo plugin to `localhost:34873` and keep the terminal running while developing.

## Data persistence

The game saves:

- after every successful action,
- every 60 seconds,
- on player leave,
- during server shutdown.

Persistence uses both:

- `GrowATinyPlanet_PlayerData_v1`
- `GrowATinyPlanet_PlayerData_Backup_v1`

Each mutation increments a revision. Loading compares primary and backup revisions, and saving uses `UpdateAsync` with retry protection so stale asynchronous writes cannot replace newer state.

If Studio API access is disabled, Studio immediately enters an unsaved test session instead of waiting through repeated DataStore retries. For persistence testing, publish the experience and enable **Game Settings → Security → Studio Access to API Services**.

## Monetization

Marketplace behavior is fully wired, but Roblox assigns asset IDs only after the assets are created for the target experience. Put those IDs in `src/ReplicatedStorage/Shared/Config.lua`.

### Game Passes

| Pass | Price | Effect |
|---|---:|---|
| Fast Growth | 299 R$ | 2× Energy regeneration speed |
| Cosmic Skin | 499 R$ | Cosmic planet surface styling |
| Starter Planet | 999 R$ | One-time 5 water + 5 plant starting development |
| Moon Companion | 799 R$ | Physical orbiting moon |

### Developer Products

| Product | Price | Effect |
|---|---:|---|
| Energy Boost | 49 R$ | +500 Energy |
| Rare Seed Pack | 99 R$ | +3 glowing rare-plant charges |
| Comet Strike | 199 R$ | Develops up to 3 random land tiles |

Developer-product receipts are persisted and only return `PurchaseGranted` after the grant has successfully reached a DataStore.

## Security model

- The client sends only an action type and optional tile index.
- The server owns Energy, tile state, costs, unlocks, habitat checks, cluster validation, milestones, and purchases.
- All tile indices are validated against the 144-tile geometry.
- The server enforces a global one-second action rate limit.
- Terraform Burst has an additional 15-second cooldown.
- Targeted invalid actions are rejected rather than redirected.
- Every player receives a separate planet slot and independent persistent state.

## Play-test checklist

1. Click anywhere on the sphere and verify the tile inspector opens.
2. Select Water, then click a land tile; verify that exact tile turns blue and Energy drops by 50.
3. Select Plants, then click another land tile; verify a physical tree appears.
4. Verify a targeted invalid action is rejected without changing a different tile.
5. Drag to orbit and scroll/pinch to zoom.
6. Verify 10 developed tiles unlock animals and award 150 Energy.
7. Verify fish require 3 water tiles and land animals require 5 plant tiles.
8. Verify 25 developed tiles unlock settlements and award 350 Energy.
9. Verify settlements require a planted tile inside a connected 5-tile developed component.
10. Verify 50 developed tiles unlock Terraform Burst and award 750 Energy.
11. Leave and rejoin and verify Energy, tiles, animals, settlements, milestones, rare-seed charges, and processed receipts restore.
12. In a 2-player Studio test, verify each client sees and controls only its own planet.
13. With real Marketplace IDs configured, verify passes update the current planet and developer products grant exactly once.
