# Salvage expeditions

Rustrail Depot and Dynamo Works extend the existing Starter Yard → Circuit Yard progression. Both are private factory-owned salvage regions. Visitors cannot collect another owner's nodes.

| Site | Unlock after | Credits | Lifetime bots | Scrap per node |
| --- | --- | ---: | ---: | ---: |
| Rustrail Depot | Circuit Yard | 8,000 | 8 | 6–10 |
| Dynamo Works | Rustrail Depot | 20,000 | 16 | 8–13 |

The two colored expedition terminals near the factory entrance unlock and transport the owner. Unlock costs are paid once. Subsequent travel and return are free. Each site contains a continuous walking loop, 12 salvage nodes, distinct industrial landmarks, and a return terminal beside the arrival point. The two far-end nodes are lost-parts caches: each adds two wiring and one power-core fragment to normal zone salvage, and respawns after 60 seconds. Other nodes retain the existing eight-second respawn.

Unlocks use the existing saved progression field and sequential server transaction. No profile schema migration is needed. Existing factory bot routes stay local; expeditions are manual exploration content. The collection transaction retains ownership, distance, unlock, capacity, and claim checks.

## Verification

On the VM or CI:

    rojo build default.project.json -o build/expeditions.rbxlx
    lune run scripts/test-expeditions.luau

The Lune harness executes production progression, objective, builder, zone service, and salvage service modules with explicitly mocked engine services. It checks affordability, sequence, saved-zone normalization, repeat travel, return, access denial, cache rewards/respawn, node spacing, approach clearance, and part budgets. It does not substitute for an interactive Roblox client playtest.

Optional native-geometry preview, retained on the VM:

    blender -b -t 2 --python tools/assets/render_expeditions.py

The live-place smoke script also checks the published expedition modules in an isolated Roblox execution session. The full Jest cloud suite requires the separate test-place configuration.
