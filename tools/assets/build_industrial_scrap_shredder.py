import bpy
import math
import os
from mathutils import Vector

OUT = "/opt/roblox-assets/scrap_shredder_blender"
os.makedirs(OUT, exist_ok=True)

# -----------------------------------------------------------------------------
# Scene
# -----------------------------------------------------------------------------
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = 1.0
scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x = 900
scene.render.resolution_y = 900
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.film_transparent = False
scene.render.image_settings.color_mode = 'RGBA'
scene.world.color = (0.018, 0.022, 0.028)
scene.render.image_settings.color_depth = '8'

# -----------------------------------------------------------------------------
# Materials - restrained industrial palette, no neon / no generic toy plastic.
# -----------------------------------------------------------------------------
def material(name, base, metallic, roughness):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*base, 1.0)
    bsdf.inputs['Metallic'].default_value = metallic
    bsdf.inputs['Roughness'].default_value = roughness
    return mat

GALV = material('GalvanizedSteel', (0.50, 0.54, 0.56), 0.82, 0.40)
CHAR = material('CharcoalSteel', (0.065, 0.075, 0.085), 0.82, 0.32)
YELLOW = material('IndustrialYellow', (0.92, 0.43, 0.018), 0.67, 0.39)
CUTTER = material('HardenedCutterSteel', (0.07, 0.075, 0.082), 0.93, 0.20)
BLUE = material('MotorBlue', (0.035, 0.18, 0.32), 0.62, 0.34)
COPPER = material('CopperFittings', (0.35, 0.12, 0.055), 0.82, 0.31)
RUBBER = material('Rubber', (0.018, 0.021, 0.025), 0.02, 0.84)
RED = material('EmergencyRed', (0.42, 0.018, 0.012), 0.35, 0.38)
CYAN = material('StatusCyan', (0.01, 0.46, 0.62), 0.15, 0.23)

EXPORT = []

# -----------------------------------------------------------------------------
# Hard-surface helpers
# -----------------------------------------------------------------------------
def apply_modifiers(obj):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    for mod in list(obj.modifiers):
        try:
            bpy.ops.object.modifier_apply(modifier=mod.name)
        except RuntimeError:
            pass
    obj.select_set(False)


def add_box(name, loc, dims, mat, bevel=0.04, rot=(0.0, 0.0, 0.0), export=True):
    bpy.ops.mesh.primitive_cube_add(location=loc, rotation=rot)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dims
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    if bevel > 0:
        bev = obj.modifiers.new('HardSurfaceBevel', 'BEVEL')
        bev.width = bevel
        bev.segments = 1
        bev.limit_method = 'ANGLE'
    if export:
        EXPORT.append(obj)
    return obj


def add_cyl(name, loc, radius, depth, mat, rot=(0.0, 0.0, 0.0), verts=16, bevel=0.025, export=True):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=loc, rotation=rot)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    if bevel > 0:
        bev = obj.modifiers.new('EdgeBevel', 'BEVEL')
        bev.width = bevel
        bev.segments = 1
        bev.limit_method = 'ANGLE'
    if export:
        EXPORT.append(obj)
    return obj


def add_sphere(name, loc, radius, mat, segments=12, rings=6, export=True):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=radius, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    if export:
        EXPORT.append(obj)
    return obj


def add_beam(name, p1, p2, radius, mat, verts=8):
    a = Vector(p1)
    b = Vector(p2)
    v = b - a
    obj = add_cyl(name, (a + b) * 0.5, radius, v.length, mat, verts=verts, bevel=0.01)
    obj.rotation_mode = 'QUATERNION'
    obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(v.normalized())
    return obj


def add_pipe(name, points, radius, mat):
    curve = bpy.data.curves.new(name + 'Curve', 'CURVE')
    curve.dimensions = '3D'
    curve.resolution_u = 1
    curve.bevel_depth = radius
    curve.bevel_resolution = 1
    spline = curve.splines.new('POLY')
    spline.points.add(len(points) - 1)
    for p, co in zip(spline.points, points):
        p.co = (*co, 1.0)
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target='MESH')
    obj = bpy.context.object
    obj.name = name
    EXPORT.append(obj)
    return obj


def add_gear_disc(name, x, y, z, width=0.30, root=0.74, tip=1.03, teeth=10, phase=0.0):
    # Extruded alternating-radius cutter disc along X. Low-poly but mechanically readable.
    radial = teeth * 2
    verts = []
    faces = []
    for sx in (-width * 0.5, width * 0.5):
        for i in range(radial):
            a = phase + i * math.pi / teeth
            r = tip if i % 2 == 0 else root
            verts.append((x + sx, y + math.cos(a) * r, z + math.sin(a) * r))
    for i in range(radial):
        j = (i + 1) % radial
        faces.append((i, j, radial + j, radial + i))
    faces.append(tuple(range(radial - 1, -1, -1)))
    faces.append(tuple(range(radial, radial * 2)))
    mesh = bpy.data.meshes.new(name + 'Mesh')
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(CUTTER)
    bev = obj.modifiers.new('CutterEdge', 'BEVEL')
    bev.width = 0.018
    bev.segments = 1
    bev.limit_method = 'ANGLE'
    EXPORT.append(obj)
    return obj


def add_trapezoid_panel(name, bottom_a, bottom_b, top_b, top_a, thickness, mat):
    # Four-corner panel with Solidify; cleaner than a generic cube used as a hopper wall.
    mesh = bpy.data.meshes.new(name + 'Mesh')
    mesh.from_pydata([bottom_a, bottom_b, top_b, top_a], [], [(0, 1, 2, 3)])
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    sol = obj.modifiers.new('PlateThickness', 'SOLIDIFY')
    sol.thickness = thickness
    sol.offset = 0
    bev = obj.modifiers.new('PlateEdge', 'BEVEL')
    bev.width = 0.035
    bev.segments = 1
    EXPORT.append(obj)
    return obj


def bolt(name, loc, mat=CHAR, axis='Y'):
    rot = (math.pi / 2, 0, 0) if axis == 'Y' else ((0, math.pi / 2, 0) if axis == 'X' else (0, 0, 0))
    return add_cyl(name, loc, 0.075, 0.07, mat, rot=rot, verts=8, bevel=0.008)

# -----------------------------------------------------------------------------
# Base skid and real structural frame
# -----------------------------------------------------------------------------
# Long channels and crossmembers
for y in (-2.45, 2.45):
    add_box('BaseLongitudinal', (0, y, 0.42), (11.7, 0.46, 0.58), CHAR, 0.055)
for x in (-5.55, 0.0, 5.55):
    add_box('BaseCrossmember', (x, 0, 0.42), (0.46, 5.35, 0.58), CHAR, 0.05)
# Machine feet and gussets
for x in (-4.75, 4.75):
    for y in (-1.9, 1.9):
        add_box('FrameLeg', (x, y, 1.65), (0.62, 0.62, 2.65), CHAR, 0.055)
        add_box('FootPlate', (x, y, 0.13), (1.05, 1.05, 0.20), CHAR, 0.035)
        add_beam('LegBrace', (x, y, 0.62), (x * 0.78, y * 0.72, 2.60), 0.105, CHAR, 8)

# -----------------------------------------------------------------------------
# Shredder chamber: layered plate construction, recessed front service panels
# -----------------------------------------------------------------------------
add_box('ChamberBody', (0, 0, 4.12), (7.85, 4.45, 3.25), GALV, 0.10)
add_box('ChamberLowerRail', (0, -2.30, 2.72), (8.10, 0.30, 0.42), CHAR, 0.045)
add_box('ChamberUpperRail', (0, -2.30, 5.58), (8.10, 0.30, 0.42), CHAR, 0.045)
# Reinforced side cheeks
for x in (-4.02, 4.02):
    add_box('SideCheek', (x, 0, 4.18), (0.48, 4.62, 3.45), CHAR, 0.08)
    add_box('SideWearPlate', (x * 1.012, -0.05, 4.18), (0.16, 3.55, 2.40), YELLOW, 0.025)

# Three recessed maintenance doors with frames, hinges and bolts
panel_xs = (-2.45, 0.0, 2.45)
for px in panel_xs:
    add_box('AccessFrame', (px, -2.405, 4.02), (2.18, 0.12, 1.86), CHAR, 0.025)
    add_box('AccessDoor', (px, -2.49, 4.02), (1.88, 0.10, 1.55), GALV, 0.025)
    add_box('DoorHandle', (px + 0.66, -2.565, 4.02), (0.10, 0.08, 0.52), CHAR, 0.015)
    for dz in (-0.59, 0.59):
        add_box('DoorHinge', (px - 0.78, -2.56, 4.02 + dz), (0.15, 0.08, 0.28), CHAR, 0.012)
    for bx in (-0.78, 0.78):
        for bz in (-0.65, 0.65):
            bolt('DoorBolt', (px + bx, -2.575, 4.02 + bz), CHAR, 'Y')
# Hazard-colored lower service rail rather than a giant painted box
add_box('SafetyLowerRail', (0, -2.50, 2.92), (7.95, 0.12, 0.28), YELLOW, 0.025)

# -----------------------------------------------------------------------------
# Twin cutter shafts and bearing housings
# -----------------------------------------------------------------------------
shaft_z = 5.48
for shaft_i, sy in enumerate((-0.78, 0.78)):
    add_cyl('CutterShaft', (0, sy, shaft_z), 0.27, 7.45, CUTTER, rot=(0, math.pi / 2, 0), verts=16, bevel=0.02)
    for i in range(9):
        x = -3.15 + i * 0.79
        add_gear_disc('CutterDisc', x, sy, shaft_z, width=0.30, root=0.72, tip=1.04, teeth=9,
                      phase=(shaft_i * math.pi / 9) + (i % 2) * math.pi / 18)
    # large bearing/flange at both sides
    for sx in (-4.16, 4.16):
        add_cyl('BearingFlange', (sx, sy, shaft_z), 0.70, 0.22, CHAR, rot=(0, math.pi / 2, 0), verts=16, bevel=0.035)
        add_cyl('BearingCap', (sx * 1.018, sy, shaft_z), 0.43, 0.18, YELLOW, rot=(0, math.pi / 2, 0), verts=16, bevel=0.025)

# -----------------------------------------------------------------------------
# Side gearboxes + dual industrial motors, with cooling fins and coupling guards
# -----------------------------------------------------------------------------
def motor(side):
    s = float(side)
    gx = s * 4.78
    mx = s * 6.05
    # gearbox housing - broad chamfered mass between motor and chamber
    add_box('GearboxHousing', (gx, 0.0, 5.42), (1.22, 3.05, 2.52), CHAR, 0.18)
    add_cyl('GearboxInputFlange', (s * 5.37, 0.0, 5.42), 0.66, 0.28, CHAR,
            rot=(0, math.pi / 2, 0), verts=16, bevel=0.035)
    # main motor shell
    add_cyl('MotorBody', (mx, 0.0, 5.42), 1.08, 1.52, BLUE,
            rot=(0, math.pi / 2, 0), verts=16, bevel=0.055)
    # end bell and fan cover
    add_cyl('MotorEndBell', (s * 6.80, 0.0, 5.42), 0.94, 0.28, BLUE,
            rot=(0, math.pi / 2, 0), verts=16, bevel=0.035)
    add_cyl('MotorFanGuard', (s * 6.97, 0.0, 5.42), 0.76, 0.12, CHAR,
            rot=(0, math.pi / 2, 0), verts=12, bevel=0.018)
    # cooling fins: thin rings parallel to motor end faces
    for ofs in (-0.48, -0.28, -0.08, 0.12, 0.32, 0.52):
        add_cyl('MotorCoolingFin', (mx + s * ofs, 0.0, 5.42), 1.13, 0.055, CHAR,
                rot=(0, math.pi / 2, 0), verts=16, bevel=0.008)
    # coupling guard and motor saddle
    add_box('CouplingGuard', (s * 5.28, -1.05, 4.83), (0.54, 0.95, 1.18), YELLOW, 0.12)
    add_box('MotorSaddle', (mx, 0.0, 4.20), (1.62, 2.36, 0.34), CHAR, 0.05)
    add_box('MotorPedestal', (mx, 0.0, 3.68), (1.08, 1.85, 0.72), CHAR, 0.05)

motor(-1)
motor(1)

# -----------------------------------------------------------------------------
# Hopper: separate trapezoidal steel plates, visible ribs, actual throat opening
# -----------------------------------------------------------------------------
zb = 5.78
zt = 9.18
bx, by = 3.55, 1.88
tx, ty = 5.35, 3.28
# front / rear
add_trapezoid_panel('HopperFront', (-bx, -by, zb), (bx, -by, zb), (tx, -ty, zt), (-tx, -ty, zt), 0.13, GALV)
add_trapezoid_panel('HopperRear', (bx, by, zb), (-bx, by, zb), (-tx, ty, zt), (tx, ty, zt), 0.13, GALV)
# sides
add_trapezoid_panel('HopperLeft', (-bx, by, zb), (-bx, -by, zb), (-tx, -ty, zt), (-tx, ty, zt), 0.13, GALV)
add_trapezoid_panel('HopperRight', (bx, -by, zb), (bx, by, zb), (tx, ty, zt), (tx, -ty, zt), 0.13, GALV)
# heavy top lip: yellow on the front and side corners, dark rear lip
add_box('HopperLipFront', (0, -ty, zt), (10.95, 0.22, 0.26), YELLOW, 0.04)
add_box('HopperLipRear', (0, ty, zt), (10.95, 0.22, 0.26), CHAR, 0.04)
add_box('HopperLipLeft', (-tx, 0, zt), (0.22, 6.52, 0.26), YELLOW, 0.04)
add_box('HopperLipRight', (tx, 0, zt), (0.22, 6.52, 0.26), YELLOW, 0.04)
# structural ribs mounted to hopper faces
for x in (-4.0, -2.0, 0.0, 2.0, 4.0):
    xb = x * (bx / tx)
    add_beam('HopperFrontRib', (xb, -by - 0.08, zb + 0.05), (x, -ty - 0.08, zt - 0.28), 0.075, CHAR, 8)
for side in (-1, 1):
    for y in (-1.65, 0.0, 1.65):
        yb = y * (by / ty)
        add_beam('HopperSideRib', (side * (bx + 0.08), yb, zb + 0.10), (side * (tx + 0.08), y, zt - 0.30), 0.07, CHAR, 8)

# -----------------------------------------------------------------------------
# Short discharge chute only. Conveyor remains a separate modular asset.
# -----------------------------------------------------------------------------
add_box('DischargeChute', (0, -2.95, 2.35), (3.55, 1.55, 0.34), GALV,
        0.06, rot=(math.radians(-18), 0, 0))
for sx in (-1.76, 1.76):
    add_box('DischargeSide', (sx, -2.95, 2.60), (0.18, 1.62, 0.72), YELLOW,
            0.04, rot=(math.radians(-18), 0, 0))

# -----------------------------------------------------------------------------
# Service details: control cabinet, indicator stack, conduit, lubrication lines
# -----------------------------------------------------------------------------
add_box('ControlCabinet', (4.72, -2.78, 2.02), (1.32, 0.66, 2.36), CHAR, 0.08)
add_box('ControlDoor', (4.72, -3.13, 2.02), (1.05, 0.10, 1.98), GALV, 0.025)
# indicators
for idx, (z, mat) in enumerate(((2.52, CYAN), (2.25, CYAN), (1.98, RED))):
    add_cyl('Indicator', (4.72, -3.205, z), 0.075 if idx < 2 else 0.11, 0.055, mat,
            rot=(math.pi / 2, 0, 0), verts=10, bevel=0.006)
# emergency stop bezel
add_cyl('EmergencyStopBezel', (5.07, -3.205, 1.62), 0.16, 0.055, YELLOW,
        rot=(math.pi / 2, 0, 0), verts=10, bevel=0.008)
add_cyl('EmergencyStop', (5.07, -3.245, 1.62), 0.11, 0.075, RED,
        rot=(math.pi / 2, 0, 0), verts=10, bevel=0.008)
# cable / lube routing
add_pipe('MainConduit', [(4.38, -2.75, 1.55), (3.95, -2.55, 1.55), (3.95, -2.45, 3.55), (4.35, -2.05, 4.18)], 0.055, CHAR)
add_pipe('LubeLineLeft', [(-3.65, -2.34, 3.20), (-4.35, -2.52, 3.20), (-4.35, -2.48, 5.48)], 0.04, COPPER)
add_pipe('LubeLineRight', [(3.65, -2.34, 3.20), (4.35, -2.52, 3.20), (4.35, -2.48, 5.48)], 0.04, COPPER)

# Small service step on front-left, grounded and believable
add_box('ServiceStepLower', (-4.95, -2.85, 0.48), (1.20, 0.82, 0.24), YELLOW, 0.035)
add_box('ServiceStepUpper', (-4.95, -2.55, 0.83), (1.20, 0.82, 0.24), CHAR, 0.035)

# -----------------------------------------------------------------------------
# Apply modeling modifiers, UVs, triangulation
# -----------------------------------------------------------------------------
mesh_objs = []
for obj in EXPORT:
    if obj.type == 'MESH':
        apply_modifiers(obj)
        mesh_objs.append(obj)

# Smart UV per-object keeps exported objects independently reusable.
for obj in mesh_objs:
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    try:
        bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.02)
    except RuntimeError:
        pass
    bpy.ops.object.mode_set(mode='OBJECT')

# Triangulate for predictable Roblox triangle stats.
for obj in mesh_objs:
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    tri = obj.modifiers.new('RobloxTriangulate', 'TRIANGULATE')
    tri.quad_method = 'BEAUTY'
    tri.ngon_method = 'BEAUTY'
    bpy.ops.object.modifier_apply(modifier=tri.name)
    obj.select_set(False)

# -----------------------------------------------------------------------------
# Preview studio
# -----------------------------------------------------------------------------
add_box('PreviewFloor', (0, 0, -0.10), (30, 30, 0.18), material('PreviewFloorMat', (0.055, 0.060, 0.068), 0.0, 0.85), 0.0, export=False)

# backdrop plane for stronger silhouette
add_box('Backdrop', (0, 6.8, 6.0), (24, 0.20, 12), material('BackdropMat', (0.025, 0.030, 0.040), 0.0, 0.92), 0.0, export=False)


def point_camera(cam, target):
    direction = Vector(target) - cam.location
    cam.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()


def make_camera(name, loc, target, lens=56):
    bpy.ops.object.camera_add(location=loc)
    cam = bpy.context.object
    cam.name = name
    cam.data.lens = lens
    point_camera(cam, target)
    return cam


def area(name, loc, energy, size, color):
    bpy.ops.object.light_add(type='AREA', location=loc)
    light = bpy.context.object
    light.name = name
    light.data.energy = energy
    light.data.shape = 'DISK'
    light.data.size = size
    light.data.color = color
    point_camera(light, (0, 0, 4.4))

area('Key', (8.5, -10.5, 15.0), 1550, 7.0, (1.00, 0.91, 0.80))
area('Fill', (-10.0, -5.0, 9.0), 900, 6.0, (0.68, 0.80, 1.00))
area('Rim', (4.0, 8.0, 13.0), 1350, 6.0, (1.00, 0.76, 0.55))
area('Top', (-1.5, 0.0, 16.0), 900, 5.0, (1.00, 1.00, 1.00))

views = [
    ('preview_three_quarter.png', (15.5, -18.0, 11.8), (0.0, -0.1, 4.45), 55),
    ('preview_front.png', (0.0, -22.0, 7.5), (0.0, 0.0, 4.35), 58),
    ('preview_side.png', (21.0, -1.0, 7.8), (0.0, 0.0, 4.4), 58),
]
for filename, loc, target, lens in views:
    cam = make_camera('Camera_' + filename, loc, target, lens)
    scene.camera = cam
    scene.render.filepath = os.path.join(OUT, filename)
    bpy.ops.render.render(write_still=True)

# -----------------------------------------------------------------------------
# Save + export
# -----------------------------------------------------------------------------
blend_path = os.path.join(OUT, 'industrial_scrap_shredder.blend')
glb_path = os.path.join(OUT, 'industrial_scrap_shredder_roblox.glb')
bpy.ops.wm.save_as_mainfile(filepath=blend_path)

bpy.ops.object.select_all(action='DESELECT')
for obj in mesh_objs:
    obj.select_set(True)
bpy.context.view_layer.objects.active = mesh_objs[0]
bpy.ops.export_scene.gltf(
    filepath=glb_path,
    export_format='GLB',
    use_selection=True,
    export_apply=True,
    export_texcoords=True,
    export_normals=True,
    export_materials='EXPORT',
    export_yup=True,
)

tris = 0
verts = 0
for obj in mesh_objs:
    obj.data.calc_loop_triangles()
    tris += len(obj.data.loop_triangles)
    verts += len(obj.data.vertices)

# Bounding box for validation.
world_points = []
for obj in mesh_objs:
    for corner in obj.bound_box:
        world_points.append(obj.matrix_world @ Vector(corner))
mins = Vector((min(p.x for p in world_points), min(p.y for p in world_points), min(p.z for p in world_points)))
maxs = Vector((max(p.x for p in world_points), max(p.y for p in world_points), max(p.z for p in world_points)))
size = maxs - mins

print('SHREDDER_BUILD_DONE')
print('objects', len(mesh_objs), 'verts', verts, 'tris', tris)
print('bounds', round(size.x, 3), round(size.y, 3), round(size.z, 3))
print('blend', blend_path)
print('glb', glb_path)
