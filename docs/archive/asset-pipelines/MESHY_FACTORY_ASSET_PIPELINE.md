> **Archived 2026-09-20:** this paid Meshy-based workflow is retired and is not part of the active production pipeline. Use `docs/FACTORY_ASSET_PIPELINE.md`. It is retained only as historical design/provenance evidence.

# Meshy Factory Asset Pipeline

Status: generation-ready batch specification. Roblox Studio is not required for this stage.

## Goal

Replace the current graybox factory presentation with an original, coherent visual kit while preserving the
existing server-authoritative collision, prompt, ownership, upgrade, storage, salvage, and robot systems.

The decorative mesh layer must never become the authority for interaction distance, machine ownership,
salvage claims, inventory, production, or monetization benefits.

## Source of truth

src/shared/Config/FactoryVisualAssets.lua is the canonical v1 asset specification.

It defines:

- family and variant names;
- machine upgrade tier mapping;
- target Roblox-space bounds;
- triangle budgets;
- texture resolution budgets;
- pivot rules;
- collision policy;
- reusable Meshy prompts;
- eventual Roblox asset IDs after moderation/import.

Do not put temporary catalog or generated asset IDs directly into gameplay services.

## Art direction

The game should read as a compact scrapyard factory rather than a generic clean sci-fi tycoon.

Visual language:

- chunky, readable silhouettes;
- rounded safety guards and modular bolted panels;
- muted steel as the main body material;
- warm brass/copper as the secondary accent;
- restrained cyan status lighting;
- repaired/reused industrial construction without visual noise;
- simple shapes that remain readable on mobile;
- no text baked into meshes or textures;
- no logos, trademarks, franchise motifs, or copied Roblox-game visual identities.

All four machine upgrade tiers keep the same footprint. Progression is shown with extra motors, tool heads,
guards, cooling hardware, storage modules, and status lighting instead of physically moving gameplay
interaction points.

## Meshy generation order

Generate in this order so the visual language is established before secondary props:

1. Processor_L1
2. Assembler_L1
3. Storage_L1
4. WorkerBot_Wheeled
5. Processor_L2 through Processor_L4
6. Assembler_L2 through Assembler_L4
7. Storage_L2 through Storage_L4
8. WorkerBot_Legged and WorkerBot_Hover
9. SalvagePile_A, SalvagePile_B, SalvagePile_C
10. conveyor kit
11. work pad
12. pipe/cable/beacon props

The first four assets are the style-lock set. Do not generate the full batch until those four look like the
same game.

## Meshy workflow

For each asset:

1. Use the exact MeshyPrompt from FactoryVisualAssets.lua.
2. Generate the base model.
3. Reject outputs with unreadable silhouettes, unsupported floating fragments, text, logos, or excessive
   micro-detail.
4. Remesh to the configured triangle budget or lower.
5. Keep one material where practical; use two only when needed for emissive/status-light separation.
6. Generate PBR textures.
7. Export GLB for the normal static prop path.
8. Export FBX only for a rigged bot that needs skeletal animation.
9. Normalize orientation and pivot before Roblox upload.
10. Record the moderated Roblox asset ID back into RobloxAssetId.

## Roblox transform convention

Final imported assets must obey these conventions:

- Y is up.
- Front faces Roblox forward (-Z).
- Upgradeable machines use BottomCenter pivot.
- Static floor props use BottomCenter.
- Hover bot uses Center pivot.
- Final bounding boxes should match Bounds from the config within 5%.
- Never change WorldService gameplay-part placement just to compensate for a bad mesh pivot.

## Collision and authority

CollisionPolicy = GameplayPrimitive means the generated mesh is presentation only.

For those assets:

- CanCollide = false;
- CanTouch = false;
- CanQuery = false unless a later presentation-only raycast specifically requires it;
- the existing gameplay primitive remains the authoritative collision and prompt anchor.

This applies to processors, assemblers, storage, salvage piles, and work pads.

Conveyors in v1 are visual modules. They must not become client-owned physics conveyors. If physical item
movement is added later, simulation remains server-authoritative and bounded.

## Geometry budgets

Hard v1 ceiling: no configured asset exceeds 5,000 triangles.

Practical targets:

- repeated small props: 350-900;
- salvage piles: 800-900;
- conveyors: 1,100-1,500;
- storage: 1,600-2,600;
- worker bots: 2,800-3,200;
- processors/assemblers: 3,000-4,800.

A visually weak 4,800-triangle model should be regenerated, not accepted merely because it is under budget.

## Texture budgets

Use:

- 512x512 for repeated props, salvage, conveyors, and low-detail storage;
- 1024x1024 for machines, robots, and high-tier storage.

Avoid unique 2K/4K textures in this batch. Reuse palette/material treatment aggressively so eight plots do
not multiply texture memory unnecessarily.

## Upgrade readability

Machine progression must remain visible from normal camera distance.

Processor:

- L1: single crusher and side motor;
- L2: reinforced shell, larger motor, twin rollers;
- L3: enclosed shredder, cooling and dual output;
- L4: overclocked turbine/conduit treatment.

Assembler:

- L1: one arm and build plate;
- L2: second tool arm and feeder;
- L3: enclosed precision gantry and multiple heads;
- L4: premium multi-axis cell and illuminated build ring.

Storage:

- L1: rugged bin bank;
- L2: stacked rack;
- L3: industrial hopper/drawer bank;
- L4: dense smart vault.

The tier silhouette changes should not alter gameplay footprint or prompt position.

## Worker-bot requirements

Bots should share one recognizable torso/head family while locomotion changes.

Required variants:

- wheeled;
- short-legged;
- hover.

Keep limb thickness mobile-readable. Avoid fingers and tiny cables. Rigged versions should use the minimum
bone count needed for idle/work locomotion. Cosmetic shell variants can come after the gameplay kit is
accepted.

## Salvage requirements

Salvage nodes must look collectible without using glow spam.

Use three broad compositions:

- sheet metal/gears/pipes;
- motors/cables/broken chassis;
- circuit housings/batteries/electronics.

Avoid dozens of tiny disconnected pieces. The authoritative collection volume remains the existing server
node, not the visible mesh.

## Import acceptance checklist

Before an asset ID is committed:

- correct family/variant;
- original visual design;
- no accidental text/logo;
- triangle budget passed;
- texture resolution passed;
- correct orientation;
- correct pivot;
- configured bounding box within 5%;
- no floating geometry;
- normals/shading acceptable;
- no unnecessary transparent surfaces;
- no embedded collision relied on for gameplay;
- moderation/upload completed;
- Roblox asset ID recorded in config;
- asset visible on low/mid mobile test hardware before full rollout.

## Runtime integration plan

Do not replace WorldService gameplay parts until moderated asset IDs exist.

The runtime visual layer should later:

1. build the existing authoritative world exactly as it does now;
2. resolve the visual asset by machine family and saved upgrade level;
3. clone/attach the decorative MeshPart or Model to the existing authoritative part;
4. disable collision/touch/query on presentation geometry;
5. preserve prompts and server-side distance checks on the authoritative primitive;
6. swap only the decorative model when an upgrade completes.

This keeps visual iteration independent from economy and security logic.
