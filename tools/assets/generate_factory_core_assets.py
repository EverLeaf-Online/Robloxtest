import bpy
import math
import os
import random
import sys
from pathlib import Path

import numpy as np

DEFAULT_OUT = Path(__file__).resolve().parents[2] / "build" / "generated_factory_assets"
OUT = Path(os.environ.get("SCRAP_BOT_ASSET_OUT", str(DEFAULT_OUT))).resolve()
TEX = OUT / "textures"
TEX.mkdir(parents=True, exist_ok=True)

random.seed(20260919)
np.random.seed(20260919)

def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.cameras, bpy.data.lights):
        for block in list(datablocks):
            if block.users == 0:
                datablocks.remove(block)

def create_texture(name, base, accent=None, chip_rate=0.0, seed=0):
    path = TEX / f"{name}.png"
    if path.exists():
        return str(path)
    rng = np.random.default_rng(seed)
    size = 512
    arr = np.zeros((size, size, 4), dtype=np.float32)
    basev = np.array(base, dtype=np.float32)
    noise = rng.normal(0.0, 0.035, (size, size, 1)).astype(np.float32)
    arr[:, :, :3] = np.clip(basev + noise, 0.0, 1.0)
    arr[:, :, 3] = 1.0

    # Long scratches.
    for _ in range(70):
        y = int(rng.integers(0, size))
        x0 = int(rng.integers(0, size - 20))
        length = int(rng.integers(12, 140))
        x1 = min(size, x0 + length)
        delta = float(rng.uniform(-0.12, 0.12))
        arr[max(0, y - 1):min(size, y + 2), x0:x1, :3] = np.clip(
            arr[max(0, y - 1):min(size, y + 2), x0:x1, :3] + delta, 0.0, 1.0
        )

    if chip_rate > 0 and accent is not None:
        accentv = np.array(accent, dtype=np.float32)
        count = int(size * size * chip_rate)
        ys = rng.integers(0, size, count)
        xs = rng.integers(0, size, count)
        for y, x in zip(ys, xs):
            r = int(rng.integers(1, 4))
            arr[max(0, y-r):min(size, y+r+1), max(0, x-r):min(size, x+r+1), :3] = accentv

    image = bpy.data.images.new(name=name, width=size, height=size, alpha=True)
    image.pixels.foreach_set(arr.ravel())
    image.filepath_raw = str(path)
    image.file_format = "PNG"
    image.save()
    bpy.data.images.remove(image)
    return str(path)

TEXTURES = {
    "galv": create_texture("galvanized_steel", (0.46, 0.49, 0.50), (0.23, 0.11, 0.05), 0.0025, 1),
    "char": create_texture("charcoal_steel", (0.095, 0.105, 0.11), (0.22, 0.12, 0.06), 0.0015, 2),
    "yellow": create_texture("industrial_yellow", (0.77, 0.52, 0.035), (0.16, 0.09, 0.035), 0.0045, 3),
    "rubber": create_texture("rubber_black", (0.035, 0.04, 0.045), None, 0.0, 4),
    "rust": create_texture("rusted_steel", (0.30, 0.15, 0.07), (0.44, 0.23, 0.09), 0.004, 5),
}

MATS = {}

def material(name, tex_path, metallic, roughness):
    if name in MATS:
        return MATS[name]
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    tex = nt.nodes.new("ShaderNodeTexImage")
    img = bpy.data.images.load(tex_path, check_existing=True)
    tex.image = img
    tex.interpolation = "Linear"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    MATS[name] = mat
    return mat

GALV = material("GalvanizedSteel", TEXTURES["galv"], 0.72, 0.48)
CHAR = material("CharcoalSteel", TEXTURES["char"], 0.62, 0.42)
YELLOW = material("IndustrialYellow", TEXTURES["yellow"], 0.48, 0.46)
RUBBER = material("RubberBlack", TEXTURES["rubber"], 0.0, 0.78)
RUST = material("RustSteel", TEXTURES["rust"], 0.56, 0.58)

def apply_bevel(obj, width=0.035, segments=1):
    if width <= 0:
        return
    mod = obj.modifiers.new("EdgeBevel", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=mod.name)

def box(name, loc, dims, mat, bevel=0.03, rot=(0,0,0)):
    bpy.ops.mesh.primitive_cube_add(location=loc, rotation=rot)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dims
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    apply_bevel(obj, min(bevel, min(dims) * 0.2), 1)
    obj.data.materials.append(mat)
    return obj

def cyl(name, loc, radius, depth, mat, rot=(0,0,0), vertices=16, bevel=0.015):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc, rotation=rot)
    obj = bpy.context.object
    obj.name = name
    apply_bevel(obj, min(bevel, radius * 0.2), 1)
    obj.data.materials.append(mat)
    return obj

def sphere(name, loc, scale, mat, segments=16, rings=8):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    return obj

def hose(name, points, radius=0.035):
    curve_data = bpy.data.curves.new(name + "_Curve", "CURVE")
    curve_data.dimensions = "3D"
    curve_data.bevel_depth = radius
    curve_data.bevel_resolution = 1
    spline = curve_data.splines.new("POLY")
    spline.points.add(len(points) - 1)
    for p, co in zip(spline.points, points):
        p.co = (*co, 1.0)
    obj = bpy.data.objects.new(name, curve_data)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(RUBBER)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    obj.select_set(False)
    return obj

def frustum(name, z0, h, topx, topy, botx, boty, mat, open_top=True):
    z1 = z0 + h
    verts = [
        (-botx/2,-boty/2,z0),(botx/2,-boty/2,z0),(botx/2,boty/2,z0),(-botx/2,boty/2,z0),
        (-topx/2,-topy/2,z1),(topx/2,-topy/2,z1),(topx/2,topy/2,z1),(-topx/2,topy/2,z1),
    ]
    faces = [(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(0,3,2,1)]
    if not open_top:
        faces.append((4,5,6,7))
    mesh = bpy.data.meshes.new(name + "_Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    apply_bevel(obj, 0.04, 1)
    return obj

def bolt_rows(x_positions, y_positions, z, mat=GALV, radius=0.045, depth=0.05):
    for x in x_positions:
        for y in y_positions:
            cyl(f"Bolt_{x:.2f}_{y:.2f}", (x,y,z), radius, depth, mat, vertices=12)

def uv_all():
    for obj in list(bpy.context.scene.objects):
        if obj.type != "MESH" or len(obj.data.polygons) == 0:
            continue
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        try:
            bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.02)
        except TypeError:
            bpy.ops.uv.smart_project(island_margin=0.02)
        bpy.ops.object.mode_set(mode="OBJECT")
        obj.select_set(False)

def ground_center():
    objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if not objs:
        return
    pts = []
    for obj in objs:
        for corner in obj.bound_box:
            pts.append(obj.matrix_world @ bpy.mathutils.Vector(corner) if hasattr(bpy, "mathutils") else None)
    # Avoid bpy.mathutils compatibility issue: use matrix multiplication manually through Vector.
    from mathutils import Vector
    pts = [obj.matrix_world @ Vector(c) for obj in objs for c in obj.bound_box]
    minx=min(p.x for p in pts); maxx=max(p.x for p in pts)
    miny=min(p.y for p in pts); maxy=max(p.y for p in pts)
    minz=min(p.z for p in pts)
    dx=-(minx+maxx)/2; dy=-(miny+maxy)/2; dz=-minz
    for obj in objs:
        obj.location.x += dx
        obj.location.y += dy
        obj.location.z += dz

def export_asset(name):
    uv_all()
    ground_center()
    d = OUT / "core" / name
    d.mkdir(parents=True, exist_ok=True)
    path = d / f"{name}.glb"
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        export_apply=True,
        export_yup=True,
        export_materials="EXPORT",
        export_texcoords=True,
        export_normals=True,
    )
    return path

def add_frame(length, width, deck_z, leg_z=0.65):
    for y in (-width/2, width/2):
        box("FrameRail", (0,y,deck_z-0.35), (length,0.16,0.22), CHAR)
    for x in (-length/2+0.45, -length/6, length/6, length/2-0.45):
        for y in (-width/2+0.08, width/2-0.08):
            box("Leg", (x,y,leg_z/2), (0.18,0.18,leg_z), CHAR)
            box("Foot", (x,y,0.04), (0.42,0.34,0.08), GALV, 0.015)

def build_conveyor(name, length=8.0, width=2.2, deck=1.35, magnet=False):
    clear_scene()
    add_frame(length, width, deck, leg_z=1.0)
    box("Belt", (0,0,deck), (length-0.45,width-0.45,0.12), RUBBER, 0.02)
    for x in np.linspace(-length/2+0.45, length/2-0.45, 9):
        cyl("Roller", (float(x),0,deck-0.06), 0.09, width-0.3, GALV, rot=(math.radians(90),0,0), vertices=12)
    for y in (-width/2, width/2):
        box("YellowGuard", (0,y,deck+0.28), (length-0.2,0.12,0.52), YELLOW, 0.025)
    for x in (-length/2+0.5,length/2-0.5):
        cyl("EndRoller", (x,0,deck), 0.20, width-0.32, CHAR, rot=(math.radians(90),0,0), vertices=16)
    if magnet:
        for x in (-2.4,2.4):
            for y in (-1.35,1.35):
                box("MagnetPost", (x,y,2.4), (0.22,0.22,3.3), CHAR)
        box("OverheadBeam", (0,0,4.0), (5.3,0.28,0.30), CHAR)
        box("MagnetHousing", (0,0,3.25), (2.8,1.8,0.55), YELLOW, 0.06)
        for x in (-0.95,0,0.95):
            cyl("Coil", (x,0,2.92), 0.23, 1.55, CHAR, rot=(math.radians(90),0,0), vertices=16)
        hose("PowerCable", [(-1.8,-1.3,3.9),(-1.1,-1.1,3.7),(-0.9,-0.7,3.45),(-0.7,-0.5,3.3)], 0.045)
    return export_asset(name)

def build_baler():
    clear_scene()
    # Main chamber and frame.
    box("Base", (0,0,0.18), (5.2,3.2,0.36), CHAR, 0.05)
    for x in (-2.35,2.35):
        for y in (-1.35,1.35):
            box("CornerPost", (x,y,1.8), (0.25,0.25,3.3), CHAR)
    box("ChamberFloor", (0,0,0.72), (3.7,2.55,0.22), GALV)
    for y in (-1.35,1.35):
        box("ChamberWall", (0.2,y,1.72), (4.0,0.18,2.05), GALV)
    box("RearWall", (2.15,0,1.72), (0.18,2.55,2.05), GALV)
    box("Door", (-1.95,0,1.72), (0.20,2.55,2.05), YELLOW, 0.04)
    # Press ram and hydraulics.
    box("PressPlate", (0.8,0,1.72), (0.28,2.30,1.75), CHAR)
    cyl("HydraulicBody", (3.05,0,1.72), 0.34, 1.65, YELLOW, rot=(0,math.radians(90),0), vertices=20)
    cyl("HydraulicRod", (1.92,0,1.72), 0.16, 1.15, GALV, rot=(0,math.radians(90),0), vertices=16)
    box("TopBeam", (0,0,3.3), (5.0,3.0,0.30), CHAR)
    box("ControlBox", (-1.4,1.82,1.65), (0.75,0.42,1.15), CHAR, 0.04)
    for z,mat in ((1.95,YELLOW),(1.62,GALV),(1.32,RUST)):
        cyl("ControlButton", (-1.4,1.58,z), 0.07, 0.06, mat, rot=(math.radians(90),0,0), vertices=12)
    hose("HydraulicHoseA", [(3.55,-0.35,2.0),(3.8,-0.5,2.35),(3.9,-0.85,1.7),(3.6,-1.0,1.1)],0.045)
    hose("HydraulicHoseB", [(3.55,0.35,1.5),(3.85,0.55,1.2),(3.8,0.9,0.9),(3.4,1.0,0.65)],0.045)
    return export_asset("hydraulic_scrap_baler")

def build_hopper():
    clear_scene()
    frustum("HopperBody", 1.05, 2.65, 4.2, 4.2, 1.7, 1.7, GALV, open_top=True)
    for x in (-1.65,1.65):
        for y in (-1.65,1.65):
            box("HopperLeg", (x,y,0.55), (0.22,0.22,1.1), CHAR)
            box("HopperFoot", (x,y,0.05), (0.50,0.50,0.10), GALV,0.02)
    for x in (-1.8,1.8):
        box("TopReinforcement", (x,0,3.68), (0.18,4.15,0.24), YELLOW)
    for y in (-1.8,1.8):
        box("TopReinforcement", (0,y,3.68), (4.15,0.18,0.24), YELLOW)
    box("DischargeGate", (0,-0.92,1.0), (1.35,0.18,0.85), YELLOW)
    return export_asset("large_scrap_hopper")

def build_material_bin():
    clear_scene()
    box("BinFloor",(0,0,0.12),(2.6,2.3,0.24),GALV)
    box("Back",(0,1.05,1.15),(2.6,0.18,2.1),GALV)
    box("Left",(-1.21,0,1.15),(0.18,2.1,2.1),GALV)
    box("Right",(1.21,0,1.15),(0.18,2.1,2.1),GALV)
    box("FrontLower",(0,-1.05,0.55),(2.6,0.18,0.85),YELLOW)
    for x in (-1.0,1.0):
        box("Skid",(x,0,0.02),(0.22,2.5,0.10),CHAR,0.015)
    return export_asset("material_bin")

def build_assembler():
    clear_scene()
    box("Base",(0,0,0.15),(6.0,4.0,0.30),CHAR,0.05)
    for x in (-2.65,2.65):
        for y in (-1.65,1.65):
            box("GantryPost",(x,y,2.05),(0.28,0.28,3.8),CHAR)
    for y in (-1.65,1.65):
        box("GantryRail",(0,y,3.85),(5.6,0.26,0.26),CHAR)
    box("Bridge",(0,0,3.62),(0.35,3.45,0.30),YELLOW)
    cyl("VerticalActuator",(0,0,2.75),0.20,1.45,YELLOW,vertices=18)
    cyl("ToolHead",(0,0,1.95),0.34,0.45,CHAR,vertices=18)
    box("Fixture",(0,0,0.72),(2.6,2.1,0.28),GALV)
    for x in (-0.9,0.9):
        for y in (-0.65,0.65):
            box("Locator",(x,y,0.98),(0.22,0.22,0.50),YELLOW,0.025)
    box("ControlPedestal",(-2.3,2.1,1.15),(0.72,0.72,1.9),CHAR,0.04)
    hose("ToolHose",[(0.25,-1.4,3.55),(0.45,-1.0,3.15),(0.35,-0.5,2.65),(0.2,-0.25,2.2)],0.045)
    return export_asset("bot_assembler_station")

def build_power_unit():
    clear_scene()
    box("Skid",(0,0,0.10),(2.5,1.45,0.20),CHAR)
    box("Tank",(0.15,0,0.65),(1.55,1.15,1.0),GALV,0.06)
    cyl("Motor",(-0.65,0,1.45),0.42,1.1,CHAR,rot=(0,math.radians(90),0),vertices=20)
    cyl("Pump",(0.05,0,1.45),0.28,0.45,YELLOW,rot=(0,math.radians(90),0),vertices=18)
    cyl("Filter",(0.75,-0.35,1.45),0.14,0.65,YELLOW,vertices=16)
    cyl("Gauge",(0.75,0.35,1.55),0.19,0.12,GALV,rot=(math.radians(90),0,0),vertices=20)
    hose("HoseA",[(0.15,-0.25,1.4),(0.5,-0.45,1.15),(0.75,-0.5,0.9)],0.04)
    hose("HoseB",[(-0.1,0.25,1.45),(0.25,0.5,1.25),(0.7,0.45,0.95)],0.04)
    return export_asset("hydraulic_power_unit")

def build_control_cabinet():
    clear_scene()
    box("Cabinet",(0,0,1.1),(1.15,0.62,2.2),CHAR,0.05)
    box("Door",(0,-0.325,1.12),(1.02,0.05,2.02),GALV,0.025)
    box("WarningPlate",(0,-0.36,1.55),(0.52,0.03,0.42),YELLOW,0.01)
    for x,z,mat in ((-0.25,1.05,YELLOW),(0,1.05,GALV),(0.25,1.05,RUST)):
        cyl("Button",(x,-0.37,z),0.07,0.05,mat,rot=(math.radians(90),0,0),vertices=12)
    cyl("Handle",(0.38,-0.39,1.25),0.035,0.35,CHAR,rot=(0,0,0),vertices=12)
    box("Plinth",(0,0,0.10),(1.3,0.78,0.20),CHAR)
    return export_asset("electrical_control_cabinet")

def build_safety_barrier():
    clear_scene()
    for x in (-1.45,1.45):
        box("Post",(x,0,0.7),(0.14,0.14,1.4),YELLOW,0.02)
        box("Foot",(x,0,0.04),(0.42,0.42,0.08),GALV,0.01)
    for z in (0.45,0.95,1.3):
        box("Rail",(0,0,z),(2.85,0.10,0.10),YELLOW,0.02)
    # dark lower mesh substitute with thin horizontal bars
    for z in np.linspace(0.18,0.75,5):
        box("MeshRail",(0,0.035,float(z)),(2.7,0.035,0.035),CHAR,0.005)
    return export_asset("safety_barrier_3m")

def build_catwalk():
    clear_scene()
    box("MainDeck",(0,0,1.65),(4.0,1.5,0.16),GALV,0.02)
    # grating slats
    for x in np.linspace(-1.85,1.85,16):
        box("GrateSlat",(float(x),0,1.76),(0.055,1.35,0.06),CHAR,0.005)
    for x in (-1.85,1.85):
        for y in (-0.65,0.65):
            box("Leg",(x,y,0.8),(0.15,0.15,1.6),CHAR)
    for y in (-0.7,0.7):
        for x in (-1.9,0,1.9):
            box("RailPost",(x,y,2.2),(0.08,0.08,1.0),YELLOW,0.01)
        for z in (2.15,2.65):
            box("Handrail",(0,y,z),(3.9,0.07,0.07),YELLOW,0.01)
    return export_asset("catwalk_module_4m")

def build_column():
    clear_scene()
    # I-beam: web and flanges
    box("Web",(0,0,2.25),(0.14,0.52,4.5),CHAR,0.015)
    box("FlangeA",(0,-0.28,2.25),(0.52,0.10,4.5),CHAR,0.015)
    box("FlangeB",(0,0.28,2.25),(0.52,0.10,4.5),CHAR,0.015)
    box("BasePlate",(0,0,0.05),(0.85,0.85,0.10),GALV,0.015)
    bolt_rows((-0.30,0.30),(-0.30,0.30),0.11,GALV,0.045,0.06)
    return export_asset("structural_column_4_5m")

def build_scrap_bale():
    clear_scene()
    # Dense crushed cube with offset plates.
    box("Core",(0,0,0.75),(2.0,1.45,1.5),RUST,0.04)
    rng=random.Random(42)
    for i in range(18):
        x=rng.uniform(-0.9,0.9); y=rng.uniform(-0.65,0.65); z=rng.uniform(0.15,1.35)
        dims=(rng.uniform(0.25,0.65),rng.uniform(0.04,0.12),rng.uniform(0.18,0.5))
        mat=GALV if i%3 else RUST
        box(f"CrushedPlate_{i}",(x,y,z),dims,mat,0.01,rot=(rng.uniform(-0.4,0.4),rng.uniform(-0.25,0.25),rng.uniform(-0.5,0.5)))
    for x in (-0.55,0.55):
        box("Band",(x,0,0.78),(0.09,1.62,1.62),CHAR,0.01)
    return export_asset("crushed_scrap_bale")

def build_scrap_pile():
    clear_scene()
    rng=random.Random(99)
    for i in range(32):
        r=(i/32)**0.5*1.5
        a=rng.random()*math.tau
        x=math.cos(a)*r+rng.uniform(-0.2,0.2)
        y=math.sin(a)*r+rng.uniform(-0.2,0.2)
        z=max(0.08, 1.0-(r/1.7))*rng.uniform(0.4,1.0)
        dims=(rng.uniform(0.25,0.9),rng.uniform(0.08,0.42),rng.uniform(0.08,0.38))
        mat=[GALV,RUST,CHAR][i%3]
        box(f"Scrap_{i}",(x,y,z),dims,mat,0.015,rot=(rng.uniform(-0.8,0.8),rng.uniform(-0.8,0.8),rng.uniform(0,math.tau)))
    return export_asset("scrap_pile_medium")

def main():
    assets = []
    assets.append(build_conveyor("infeed_conveyor_8m", 8.0, 2.2, 1.35, False))
    assets.append(build_conveyor("outfeed_conveyor_6m", 6.0, 1.8, 1.05, False))
    assets.append(build_conveyor("magnetic_sorting_conveyor", 8.0, 2.2, 1.35, True))
    assets.append(build_baler())
    assets.append(build_hopper())
    assets.append(build_material_bin())
    assets.append(build_assembler())
    assets.append(build_power_unit())
    assets.append(build_control_cabinet())
    assets.append(build_safety_barrier())
    assets.append(build_catwalk())
    assets.append(build_column())
    assets.append(build_scrap_bale())
    assets.append(build_scrap_pile())
    print("GENERATED")
    for p in assets:
        print(p)

if __name__ == "__main__":
    main()
