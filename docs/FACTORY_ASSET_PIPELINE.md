# Scrap-to-Bot Factory — Factory Asset Pipeline

Status: **Active production specification**  
Last updated: **2026-09-20**

## Purpose

Build and maintain a coherent, performant industrial factory kit without coupling gameplay authority to presentation assets or to a paid generative-asset service.

**Paid per-generation 3D AI services are not part of the active production workflow.** Prefer assets we already own, manual Blender work, and clearly licensed/free source material where it saves development time.

## Source of truth

`src/shared/Config/FactoryVisualAssets.lua` is the canonical v1 visual-asset specification.

Each asset specification defines:

- family and variant;
- machine upgrade-tier mapping;
- target Roblox-space bounds;
- triangle and texture budgets;
- pivot and collision policy;
- final Roblox asset ID when applicable;
- an `AssetBrief` describing the intended visual result.

Do not place temporary catalog IDs or unreviewed external asset IDs directly into gameplay services.

## Approved production paths

Use these in priority order:

1. **Existing original project assets** — reuse and improve assets already created for Scrap-to-Bot Factory.
2. **Blender/manual production** — model, repair, retopologize, UV, texture, pivot, and optimize assets directly.
3. **Clearly licensed free source assets/textures** — CC0/permissive sources such as Poly Haven when appropriate, with provenance retained.
4. **Roblox Creator Store assets** — only after source/license review and only when they fit the game's original visual identity.
5. **Other tooling** — only when it does not create an ongoing paid-generation dependency and the result has clear commercial-use rights.

Never copy another Roblox game's proprietary assets, branded designs, logos, or trademarked visual identity.

## Art direction

The game should read as a compact scrapyard factory rather than a generic clean sci-fi tycoon.

Visual language:

- chunky, readable silhouettes;
- worn galvanized/muted steel as the primary material family;
- charcoal/dark industrial steel for structure and machine mass;
- restrained industrial-yellow safety accents;
- limited copper/brass wiring and mechanical accents;
- small status lights rather than glow-heavy surfaces;
- repaired/reused industrial construction without visual noise;
- simple shapes that remain readable on mobile;
- no baked-in text, logos, trademarks, or copied franchise motifs.

Upgradeable machines preserve their gameplay footprint. Progression is shown through added motors, rollers, guards, tool heads, cooling hardware, storage modules, lighting, and surface treatment rather than moving authoritative interaction points.

## Asset workflow

1. Start from the matching `AssetBrief`.
2. Confirm the source is original or has acceptable commercial-use licensing.
3. Model/repair in Blender as needed.
4. Remove floating fragments, hidden geometry, excessive micro-detail, and unnecessary materials.
5. Retopologize or decimate to the configured triangle budget or lower.
6. Keep one material where practical; add materials only when they materially improve readability.
7. Keep textures within the configured resolution budget.
8. Normalize orientation, scale, and pivot before Roblox import.
9. Export GLB for static props; use FBX only where a rigged workflow requires it.
10. Import into Roblox and verify moderation/rendering.
11. Record the final asset ID only after the asset passes acceptance.
12. Test the asset in the actual factory layout before considering it complete.

## Roblox transform convention

- Y is up.
- Front faces Roblox forward (-Z).
- Upgradeable machines use `BottomCenter` pivot.
- Static floor props use `BottomCenter`.
- Hovering visuals may use `Center`.
- Bounding boxes should match configured `Bounds` within roughly 5%.
- Do not move server-authored gameplay geometry to compensate for a bad decorative mesh pivot.

## Collision and authority

`CollisionPolicy = "GameplayPrimitive"` means the mesh/model is presentation only.

For presentation geometry:

- `CanCollide = false`;
- `CanTouch = false`;
- `CanQuery = false` unless a deliberate presentation-only query requires it;
- prompts, distance checks, ownership, salvage claims, production, inventory, and monetization remain server-authoritative.

Conveyors are visual modules unless a future bounded server-authoritative simulation explicitly says otherwise.

## Geometry budgets

Hard v1 ceiling: **5,000 triangles per configured asset**.

- repeated small props: 350–900;
- salvage piles: 800–900;
- conveyors: 1,100–1,500;
- storage: 1,600–2,600;
- worker bots: 2,800–3,200;
- processors/assemblers: 3,000–4,800.

## Texture budgets

- 512×512 for repeated props, salvage, conveyors, and low-detail storage;
- 1024×1024 for machines, robots, and high-tier storage.

Avoid unique 2K/4K textures for repeated gameplay assets. Reuse material families aggressively so multiple factories do not multiply texture memory unnecessarily.

## Import acceptance checklist

- correct family/variant;
- original or appropriately licensed source;
- provenance/license recorded for external source material;
- no accidental text/logo/trademark;
- triangle and texture budgets passed;
- correct orientation and pivot;
- configured bounds within tolerance;
- no floating or hidden junk geometry;
- normals/shading acceptable;
- no unnecessary transparent surfaces;
- presentation geometry does not own gameplay collision;
- moderation/upload completed if using an uploaded Roblox asset;
- final ID/config reference recorded;
- verified in the real factory layout;
- checked on representative mobile hardware before broad rollout.

## Runtime integration rule

The visual layer remains independent from economy/security logic:

1. build authoritative world/gameplay primitives;
2. resolve the visual asset from family + saved upgrade level;
3. attach/position the decorative mesh/model;
4. disable collision/touch/query for presentation geometry unless explicitly required;
5. preserve prompts and server-side distance checks on authoritative primitives;
6. swap only decorative visuals when upgrades change.

This lets art improve continuously without risking factory authority, persistence, or monetization correctness.
