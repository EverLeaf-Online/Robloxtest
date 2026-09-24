"""Finalize one atlas-optimized factory GLB for Roblox.

Usage:
  blender -b --python tools/assets/finalize_factory_hardsurface_asset.py -- source.glb output.glb target_triangles
"""
import sys
from pathlib import Path

import bpy
from mathutils import Vector

sep = sys.argv.index("--")
source = Path(sys.argv[sep + 1]).resolve()
dest = Path(sys.argv[sep + 2]).resolve()
target = int(sys.argv[sep + 3])

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source))
objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
if not objs:
    raise RuntimeError("source GLB has no mesh")

# Join if a future optimizer leaves more than one primitive.
bpy.ops.object.select_all(action="DESELECT")
for o in objs:
    o.select_set(True)
bpy.context.view_layer.objects.active = objs[0]
if len(objs) > 1:
    bpy.ops.object.join()
obj = bpy.context.view_layer.objects.active

obj.data.calc_loop_triangles()
start = len(obj.data.loop_triangles)
if start > target:
    dec = obj.modifiers.new("RobloxTriangleBudget", "DECIMATE")
    dec.decimate_type = "COLLAPSE"
    dec.ratio = max(0.05, min(1.0, target / start))
    dec.use_collapse_triangulate = True
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=dec.name)

tri = obj.modifiers.new("ExportTriangulate", "TRIANGULATE")
bpy.context.view_layer.objects.active = obj
bpy.ops.object.modifier_apply(modifier=tri.name)

# Remove coincident duplicate vertices conservatively after collapse.
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.remove_doubles(threshold=0.00005)
bpy.ops.object.mode_set(mode="OBJECT")

# Bottom-center pivot convention: authored geometry centered in X/Y and grounded at Z=0.
pts = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
minx, maxx = min(p.x for p in pts), max(p.x for p in pts)
miny, maxy = min(p.y for p in pts), max(p.y for p in pts)
minz = min(p.z for p in pts)
obj.location += Vector((-(minx + maxx) * 0.5, -(miny + maxy) * 0.5, -minz))
bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)

obj.data.calc_loop_triangles()
final = len(obj.data.loop_triangles)
if final > target + max(20, int(target * 0.015)):
    raise RuntimeError(f"triangle target missed: {final} > {target}")

# Keep only the model itself in the export.
bpy.ops.object.select_all(action="DESELECT")
obj.select_set(True)
bpy.context.view_layer.objects.active = obj
dest.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.export_scene.gltf(
    filepath=str(dest),
    export_format="GLB",
    use_selection=True,
    export_apply=True,
    export_texcoords=True,
    export_normals=True,
    export_tangents=False,
    export_materials="EXPORT",
    export_animations=False,
    export_skins=False,
    export_yup=True,
)

print("FINALIZED", source.name, "start", start, "final", final, "target", target,
      "materials", len(obj.data.materials), "output", dest)
