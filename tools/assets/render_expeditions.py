"""Render native expedition geometry exported by scripts/test-expeditions.luau.
blender -b -t 2 --python tools/assets/render_expeditions.py
Outputs remain in the ignored build directory.
"""
import json
import math
from pathlib import Path
import bpy
from mathutils import Vector, Matrix, Euler

geometry = json.loads(Path("build/expeditions-geometry.json").read_text())
for zone in (3, 4):
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    origin = (-420, -80 if zone == 3 else -350)
    materials = {}
    for item in geometry:
        if item["zone"] != zone or item["name"] == "ExpeditionArrival":
            continue
        px, py, pz = item["position"]
        sx, sy, sz = item["size"]
        position = (px-origin[0], -(pz-origin[1]), py)
        if item["shape"] == "Cylinder":
            bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=1, depth=2, location=position)
            obj = bpy.context.object
            # Bake the mesh onto Roblox local X, then scale in that local frame.
            rotation = Matrix.Rotation(math.pi/2, 4, "Y")
            for vertex in obj.data.vertices:
                vertex.co = rotation @ vertex.co
                vertex.co.x *= sx/2
                vertex.co.y *= sy/2
                vertex.co.z *= sz/2
        else:
            bpy.ops.mesh.primitive_cube_add(size=1, location=position)
            obj = bpy.context.object
            for vertex in obj.data.vertices:
                vertex.co.x *= sx
                vertex.co.y *= sy
                vertex.co.z *= sz
        rx, ry, rz = item["rotation"]
        source_rotation = Euler(tuple(math.radians(v) for v in (rx,ry,rz)), "YXZ").to_matrix()
        basis = Matrix(((1,0,0),(0,0,-1),(0,1,0)))
        for vertex in obj.data.vertices:
            vertex.co = basis @ source_rotation @ vertex.co
        obj.name = item["name"]
        color = tuple(item["color"])
        if color not in materials:
            mat = bpy.data.materials.new(str(color))
            mat.diffuse_color = (*color, 1)
            materials[color] = mat
        obj.data.materials.append(materials[color])
        bevel = obj.modifiers.new("Edges", "BEVEL")
        bevel.width = .16
        bevel.segments = 1
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 16
    scene.cycles.use_denoising = False
    scene.world.color = (.3, .3, .3)
    bpy.ops.object.light_add(type="AREA", location=(0, -20, 160))
    bpy.context.object.data.energy = 160000
    bpy.context.object.data.shape = "DISK"
    bpy.context.object.data.size = 140
    bpy.ops.object.camera_add(location=(170, -215, 205))
    camera = bpy.context.object
    camera.rotation_euler = (Vector((0, 0, 4))-camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 255
    scene.camera = camera
    scene.render.resolution_x = 1100
    scene.render.resolution_y = 1000
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "JPEG"
    scene.render.filepath = str(Path(f"build/expedition-{zone}.jpg").resolve())
    bpy.ops.wm.save_as_mainfile(filepath=str(Path(f"build/expedition-{zone}.blend").resolve()))
    bpy.ops.render.render(write_still=True)
