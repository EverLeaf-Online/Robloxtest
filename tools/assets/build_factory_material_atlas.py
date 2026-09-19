#!/usr/bin/env python3
"""Build the shared factory PBR atlas used by optimized Roblox GLBs."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image

ATLAS_COLUMNS = 4
ATLAS_ROWS = 2
TILE_SIZE = 512

MATERIALS = {
    "GalvanizedSteel": ("galvanized_steel.png", 0, 0, 0.72, 0.48),
    "CharcoalSteel": ("charcoal_steel.png", 1, 0, 0.62, 0.42),
    "IndustrialYellow": ("industrial_yellow.png", 2, 0, 0.48, 0.46),
    "RubberBlack": ("rubber_black.png", 3, 0, 0.00, 0.78),
    "RustSteel": ("rusted_steel.png", 0, 1, 0.56, 0.58),
}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--textures", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()

    args.output_dir.mkdir(parents=True, exist_ok=True)
    size = (ATLAS_COLUMNS * TILE_SIZE, ATLAS_ROWS * TILE_SIZE)
    base = Image.new("RGBA", size, (255, 255, 255, 255))
    metallic_roughness = Image.new("RGBA", size, (255, 128, 0, 255))

    for _, (filename, column, row_from_bottom, metallic, roughness) in MATERIALS.items():
        image = Image.open(args.textures / filename).convert("RGBA")
        image = image.resize((TILE_SIZE, TILE_SIZE))
        paste_y = (ATLAS_ROWS - 1 - row_from_bottom) * TILE_SIZE
        paste_x = column * TILE_SIZE
        base.paste(image, (paste_x, paste_y))

        mr_tile = Image.new(
            "RGBA",
            (TILE_SIZE, TILE_SIZE),
            (255, round(roughness * 255), round(metallic * 255), 255),
        )
        metallic_roughness.paste(mr_tile, (paste_x, paste_y))

    base.save(args.output_dir / "factory_material_atlas.png", optimize=True)
    metallic_roughness.save(
        args.output_dir / "factory_metallic_roughness_atlas.png",
        optimize=True,
    )


if __name__ == "__main__":
    main()
