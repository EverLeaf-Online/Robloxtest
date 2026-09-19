"""Blender-side optimizer for generated Scrap-to-Bot Factory GLBs.

Usage:
  blender -b --python tools/assets/optimize_factory_glb.py --     source.glb output.glb factory_material_atlas.png factory_metallic_roughness_atlas.png
"""

from __future__ import annotations

import sys
from pathlib import Path

import bpy
from mathutils import Vector

ATLAS_COLUMNS = 4
ATLAS_ROWS = 2

MATERIAL_SLOTS = {
    "GalvanizedSteel": (0, 0),
    "CharcoalSteel": (1, 0),
    "IndustrialYellow": (2, 0),
    "RubberBlack": (3, 0),
    "RustSteel": (0, 1),
}


def parse_args() -> tuple[Path, Path, Path, Path]:
    separator = sys.argv.index("--")
    args = [Path(value) for value in sys.argv[separator + 1 :]]
    if len(args) != 4:
        raise SystemExit("expected source.glb output.glb base_atlas.png mr_atlas.png")
    return args[0], args[1], args[2], args[3]


def create_atlas_material(base_atlas: Path, mr_atlas: Path):
    material = bpy.data.materials.new("FactoryMaterialAtlas")
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    nodes.clear()

    output = nodes.new("ShaderNodeOutputMaterial")
    principled = nodes.new("ShaderNodeBsdfPrincipled")

    base_texture = nodes.new("ShaderNodeTexImage")
    base_texture.image = bpy.data.images.load(str(base_atlas), check_existing=True)
    base_texture.interpolation = "Linear"

    mr_texture = nodes.new("ShaderNodeTexImage")
    mr_image = bpy.data.images.load(str(mr_atlas), check_existing=True)
    mr_image.colorspace_settings.name = "Non-Color"
    mr_texture.image = mr_image
    mr_texture.interpolation = "Linear"

    separate = nodes.new("ShaderNodeSeparateColor")
    links.new(base_texture.outputs["Color"], principled.inputs["Base Color"])
    links.new(mr_texture.outputs["Color"], separate.inputs["Color"])
    links.new(separate.outputs["Green"], principled.inputs["Roughness"])
    links.new(separate.outputs["Blue"], principled.inputs["Metallic"])
    links.new(principled.outputs["BSDF"], output.inputs["Surface"])
    return material


def main() -> None:
    source, destination, base_atlas, mr_atlas = parse_args()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source))

    objects = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not objects:
        raise RuntimeError("source GLB contains no mesh objects")

    atlas_material = create_atlas_material(base_atlas, mr_atlas)

    for obj in objects:
        mesh = obj.data
        if not mesh.uv_layers:
            raise RuntimeError(f"{obj.name} has no UV layer")

        material_names = [material.name if material else "" for material in mesh.materials]
        uv_data = mesh.uv_layers.active.data

        for polygon in mesh.polygons:
            if polygon.material_index >= len(material_names):
                raise RuntimeError(f"{obj.name} has an invalid material index")
            material_name = material_names[polygon.material_index]
            slot = MATERIAL_SLOTS.get(material_name)
            if slot is None:
                raise RuntimeError(f"unsupported material {material_name!r} in {obj.name}")

            column, row_from_bottom = slot
            for loop_index in polygon.loop_indices:
                uv = uv_data[loop_index].uv
                uv.x = (uv.x + column) / ATLAS_COLUMNS
                uv.y = (uv.y + row_from_bottom) / ATLAS_ROWS
            polygon.material_index = 0

        mesh.materials.clear()
        mesh.materials.append(atlas_material)

    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()

    joined = bpy.context.view_layer.objects.active
    joined.name = source.stem + "_Optimized"
    joined.data.name = joined.name + "_Mesh"

    # Remove sub-millimeter export drift without moving the authored X/Z pivot.
    min_z = min((joined.matrix_world @ Vector(corner)).z for corner in joined.bound_box)
    joined.location.z -= min_z

    destination.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(destination),
        export_format="GLB",
        export_apply=True,
        export_yup=True,
        export_materials="EXPORT",
        export_texcoords=True,
        export_normals=True,
        export_tangents=False,
        export_animations=False,
        export_skins=False,
    )


if __name__ == "__main__":
    main()
