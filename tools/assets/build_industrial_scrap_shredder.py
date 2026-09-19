import bpy
import math
import os
import random
import numpy as np
from mathutils import Vector

OUT = "/opt/roblox-assets/scrap_shredder_blender"
os.makedirs(OUT, exist_ok=True)
random.seed(19)
np.random.seed(19)

# ---------- scene ----------
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.images, bpy.data.cameras, bpy.data.lights):
    pass
scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = 1.0
scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x = 1024
scene.render.resolution_y = 1024
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.film_transparent = False
scene.world.color = (0.025, 0.03, 0.035)

# ---------- texture generation ----------
def save_img(name, rgba, colorspace='sRGB'):
    h, w, _ = rgba.shape
    img = bpy.data.images.new(name, width=w, height=h, alpha=True)
    img.colorspace_settings.name = colorspace
    img.pixels.foreach_set(rgba.astype(np.float32).ravel())
    path = os.path.join(OUT, name + '.png')
    img.filepath_raw = path
    img.file_format = 'PNG'
    img.save()
    return img

def metal_maps(prefix, base, wear=(0.32,0.34,0.36), chip=0.025, rough=0.38, seed=0):
    rng = np.random.default_rng(seed)
    s = 512
    n = rng.normal(0, 0.035, (s,s)).astype(np.float32)
    fine = rng.normal(0, 0.012, (s,s)).astype(np.float32)
    arr = np.zeros((s,s,4), np.float32)
    for c in range(3):
        arr[:,:,c] = np.clip(base[c] + n + fine, 0, 1)
    arr[:,:,3] = 1.0

    # chipped paint / abrasion speckle
    chips = rng.random((s,s)) < chip
    for c in range(3):
        arr[:,:,c][chips] = np.clip(wear[c] + rng.normal(0,0.03,chips.sum()), 0, 1)

    # sparse scratches
    for _ in range(130):
        y = int(rng.integers(0,s))
        x0 = int(rng.integers(0,s-30))
        ln = int(rng.integers(12,110))
        val = float(rng.uniform(0.08,0.22))
        arr[max(0,y-1):min(s,y+1), x0:min(s,x0+ln), :3] = np.clip(
            arr[max(0,y-1):min(s,y+1), x0:min(s,x0+ln), :3] + val, 0, 1
        )

    r = np.zeros((s,s,4), np.float32)
    rv = np.clip(rough + rng.normal(0,0.08,(s,s)), 0.12, 0.9)
    r[:,:,:3] = rv[:,:,None]
    r[:,:,3] = 1.0

    # normal from low-amplitude height field
    hgt = rng.normal(0,1,(s,s)).astype(np.float32)
    for _ in range(4):
        hgt = (hgt + np.roll(hgt,1,0)+np.roll(hgt,-1,0)+np.roll(hgt,1,1)+np.roll(hgt,-1,1))/5.0
    dx = np.roll(hgt,-1,1) - np.roll(hgt,1,1)
    dy = np.roll(hgt,-1,0) - np.roll(hgt,1,0)
    strength = 0.11
    nx = -dx*strength
    ny = -dy*strength
    nz = np.ones_like(nx)
    mag = np.sqrt(nx*nx + ny*ny + nz*nz)
    normal = np.zeros((s,s,4),np.float32)
    normal[:,:,0] = nx/mag*0.5+0.5
    normal[:,:,1] = ny/mag*0.5+0.5
    normal[:,:,2] = nz/mag*0.5+0.5
    normal[:,:,3] = 1.0

    return (
        save_img(prefix+'_base', arr, 'sRGB'),
        save_img(prefix+'_rough', r, 'Non-Color'),
        save_img(prefix+'_normal', normal, 'Non-Color')
    )

def hazard_map():
    s=512
    arr=np.zeros((s,s,4),np.float32)
    yy,xx=np.indices((s,s))
    stripe=((xx+yy)//64)%2
    yellow=np.array([0.95,0.56,0.02],np.float32)
    black=np.array([0.035,0.04,0.045],np.float32)
    arr[:,:,:3]=np.where(stripe[:,:,None]==0,yellow,black)
    rng=np.random.default_rng(77)
    grime=rng.normal(0,0.035,(s,s,1)).astype(np.float32)
    arr[:,:,:3]=np.clip(arr[:,:,:3]+grime,0,1)
    arr[:,:,3]=1.0
    return save_img('hazard_base',arr,'sRGB')

galv_imgs = metal_maps('galv', (0.52,0.56,0.58), wear=(0.30,0.33,0.35), chip=0.012, rough=0.43, seed=11)
char_imgs = metal_maps('charcoal', (0.07,0.085,0.10), wear=(0.34,0.36,0.38), chip=0.018, rough=0.34, seed=22)
yellow_imgs = metal_maps('yellow', (0.92,0.52,0.015), wear=(0.13,0.14,0.15), chip=0.035, rough=0.42, seed=33)
hard_imgs = metal_maps('hardened', (0.055,0.065,0.075), wear=(0.20,0.22,0.24), chip=0.008, rough=0.24, seed=44)
rubber_imgs = metal_maps('rubber', (0.025,0.03,0.035), wear=(0.06,0.065,0.07), chip=0.003, rough=0.78, seed=55)
hazard_img = hazard_map()

def make_mat(name, imgs=None, metallic=0.8, roughness=0.4, base=(0.5,0.5,0.5,1), hazard=False):
    mat=bpy.data.materials.new(name)
    mat.use_nodes=True
    mat.diffuse_color=base
    bsdf=mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value=base
    bsdf.inputs['Metallic'].default_value=metallic
    bsdf.inputs['Roughness'].default_value=roughness
    nt=mat.node_tree
    if hazard:
        tex=nt.nodes.new('ShaderNodeTexImage'); tex.image=hazard_img
        nt.links.new(tex.outputs['Color'],bsdf.inputs['Base Color'])
        bsdf.inputs['Metallic'].default_value=0.7
        bsdf.inputs['Roughness'].default_value=0.42
    elif imgs:
        base_img, rough_img, norm_img = imgs
        t0=nt.nodes.new('ShaderNodeTexImage'); t0.image=base_img
        tr=nt.nodes.new('ShaderNodeTexImage'); tr.image=rough_img
        tn=nt.nodes.new('ShaderNodeTexImage'); tn.image=norm_img
        nm=nt.nodes.new('ShaderNodeNormalMap'); nm.inputs['Strength'].default_value=0.35
        nt.links.new(t0.outputs['Color'],bsdf.inputs['Base Color'])
        nt.links.new(tr.outputs['Color'],bsdf.inputs['Roughness'])
        nt.links.new(tn.outputs['Color'],nm.inputs['Color'])
        nt.links.new(nm.outputs['Normal'],bsdf.inputs['Normal'])
    return mat

MAT_GALV=make_mat('Worn_Galvanized',galv_imgs,0.82,0.43,(0.52,0.56,0.58,1))
MAT_CHAR=make_mat('Charcoal_Steel',char_imgs,0.80,0.34,(0.07,0.085,0.10,1))
MAT_YEL=make_mat('Industrial_Yellow',yellow_imgs,0.72,0.42,(0.92,0.52,0.015,1))
MAT_HARD=make_mat('Hardened_Cutter_Steel',hard_imgs,0.92,0.24,(0.055,0.065,0.075,1))
MAT_RUB=make_mat('Conveyor_Rubber',rubber_imgs,0.02,0.78,(0.025,0.03,0.035,1))
MAT_HAZ=make_mat('Safety_Hazard',hazard=True)

EXPORT=[]

def finish(obj, mat, bevel=0.0, smooth=False):
    obj.data.materials.append(mat)
    if bevel>0:
        bev=obj.modifiers.new('EdgeBevel','BEVEL')
        bev.width=bevel
        bev.segments=2
        bev.limit_method='ANGLE'
    if smooth:
        for p in obj.data.polygons:
            p.use_smooth=True
    EXPORT.append(obj)
    return obj

def box(name, loc, dims, mat, rot=(0,0,0), bevel=0.06):
    bpy.ops.mesh.primitive_cube_add(location=loc, rotation=rot)
    o=bpy.context.object; o.name=name
    o.dimensions=dims
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(o,mat,bevel,False)

def cyl(name, loc, radius, depth, mat, rot=(0,0,0), verts=24, bevel=0.04):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=loc, rotation=rot)
    o=bpy.context.object; o.name=name
    return finish(o,mat,bevel,True)

def beam(name, p1, p2, radius, mat, verts=12):
    a=Vector(p1); b=Vector(p2); v=b-a; ln=v.length
    mid=(a+b)/2
    o=cyl(name,mid,radius,ln,mat,verts=verts,bevel=0.015)
    o.rotation_mode='QUATERNION'
    o.rotation_quaternion=Vector((0,0,1)).rotation_difference(v.normalized())
    return o

def star_prism(name, x, y, z, width, r1, r2, points, phase=0.0):
    verts=[]; faces=[]
    n=points*2
    for sx in (-width/2,width/2):
        for i in range(n):
            a=phase + i*math.pi/points
            r=r1 if i%2==0 else r2
            verts.append((x+sx,y+math.cos(a)*r,z+math.sin(a)*r))
    for i in range(n):
        j=(i+1)%n
        faces.append((i,j,n+j,n+i))
    faces.append(tuple(range(n-1,-1,-1)))
    faces.append(tuple(range(n,2*n)))
    me=bpy.data.meshes.new(name+'Mesh')
    me.from_pydata(verts,[],faces); me.update()
    o=bpy.data.objects.new(name,me); bpy.context.collection.objects.link(o)
    return finish(o,MAT_HARD,0.035,False)

def hopper():
    bx,by=7.6/2,4.3/2
    tx,ty=11.0/2,7.0/2
    zb,zt=6.55,9.5
    vs=[
        (-bx,-by,zb),(bx,-by,zb),(bx,by,zb),(-bx,by,zb),
        (-tx,-ty,zt),(tx,-ty,zt),(tx,ty,zt),(-tx,ty,zt)
    ]
    fs=[(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
    me=bpy.data.meshes.new('HopperMesh'); me.from_pydata(vs,[],fs); me.update()
    o=bpy.data.objects.new('Feed_Hopper',me); bpy.context.collection.objects.link(o)
    o.data.materials.append(MAT_GALV)
    sol=o.modifiers.new('HopperThickness','SOLIDIFY'); sol.thickness=0.14
    bev=o.modifiers.new('HopperBevel','BEVEL'); bev.width=0.055; bev.segments=2
    EXPORT.append(o)
    # top rim
    box('HopperRimFront',(0,-ty,zt),(11.15,0.18,0.22),MAT_YEL,bevel=0.04)
    box('HopperRimRear',(0,ty,zt),(11.15,0.18,0.22),MAT_YEL,bevel=0.04)
    box('HopperRimLeft',(-tx,0,zt),(0.18,7.05,0.22),MAT_YEL,bevel=0.04)
    box('HopperRimRight',(tx,0,zt),(0.18,7.05,0.22),MAT_YEL,bevel=0.04)
    # outer ribs on front face
    for x in (-4.2,-2.1,0,2.1,4.2):
        beam('HopperRib', (x*0.70,-by-0.07,zb+0.05), (x,-ty-0.07,zt-0.12), 0.075, MAT_CHAR, 8)

# ---------- heavy base / frame ----------
for y in (-2.8,2.8):
    box('BaseCross',(0,y,0.35),(12.2,0.42,0.52),MAT_CHAR)
for x in (-5.8,5.8):
    box('BaseSide',(x,0,0.35),(0.42,5.7,0.52),MAT_CHAR)
for x in (-5.35,5.35):
    for y in (-2.25,2.25):
        box('FrameColumn',(x,y,2.15),(0.52,0.52,3.9),MAT_CHAR)
        box('FootPlate',(x,y,0.16),(0.95,0.95,0.18),MAT_CHAR,bevel=0.03)
# diagonals
for x in (-5.35,5.35):
    beam('FrameBrace',(x,-2.2,0.6),(x,2.2,3.15),0.11,MAT_CHAR,8)
    beam('FrameBrace',(x,2.2,0.6),(x,-2.2,3.15),0.11,MAT_CHAR,8)
for y in (-2.25,2.25):
    beam('FrameBrace',(-5.2,y,0.65),(-2.7,y,3.1),0.11,MAT_CHAR,8)
    beam('FrameBrace',(5.2,y,0.65),(2.7,y,3.1),0.11,MAT_CHAR,8)

# ---------- shredder chamber ----------
box('ChamberLower',(0,0,3.45),(7.9,4.45,0.45),MAT_CHAR)
box('ChamberUpper',(0,0,6.45),(7.9,4.45,0.45),MAT_CHAR)
for x in (-3.95,3.95):
    box('ChamberSide',(x,0,4.95),(0.62,4.45,3.45),MAT_CHAR)
# rear enclosure
box('RearWall',(0,2.13,4.95),(7.5,0.22,2.9),MAT_CHAR,bevel=0.04)
# front maintenance fascia
box('FrontFascia',(0,-2.29,3.92),(7.5,0.20,0.95),MAT_GALV,bevel=0.035)
for x in (-2.55,0,2.55):
    box('AccessPanel',(x,-2.405,3.92),(2.18,0.08,0.68),MAT_GALV,bevel=0.025)
    for sx in (-0.92,0.92):
        cyl('PanelBolt',(x+sx,-2.47,3.92),0.055,0.08,MAT_CHAR,rot=(math.pi/2,0,0),verts=12,bevel=0.01)
box('HazardBand',(0,-2.41,3.30),(7.55,0.10,0.42),MAT_HAZ,bevel=0.02)

# cutter shafts and toothed wheels
for yi,zi,phase in [(-0.72,5.15,0.0),(0.72,5.0,math.pi/12)]:
    cyl('CutterShaft',(0,yi,zi),0.34,7.3,MAT_HARD,rot=(0,math.pi/2,0),verts=24,bevel=0.03)
    xs=np.linspace(-3.2,3.2,12)
    for i,x in enumerate(xs):
        star_prism('CutterWheel',float(x),yi,zi,0.42,1.02,1.35,6,phase+(i%2)*math.pi/12)

# side gearbox shoulders
for x in (-4.55,4.55):
    box('Gearbox',(x,0,5.05),(1.05,3.75,2.7),MAT_CHAR,bevel=0.15)

# ---------- motors / drive assemblies ----------
for side in (-1,1):
    x=side*5.55
    cyl('MainMotor',(x,0.25,5.25),1.22,1.65,MAT_CHAR,rot=(0,math.pi/2,0),verts=28,bevel=0.08)
    cyl('MotorEnd',(side*6.25,0.25,5.25),1.12,0.28,MAT_YEL,rot=(0,math.pi/2,0),verts=28,bevel=0.06)
    box('DriveGuard',(side*5.05,-1.35,4.65),(1.45,1.35,1.75),MAT_YEL,bevel=0.15)
    # cooling ribs
    for yy in (-0.55,-0.25,0.05,0.35,0.65,0.95):
        cyl('MotorRib',(x,yy,5.25),1.28,0.07,MAT_CHAR,rot=(math.pi/2,0,0),verts=20,bevel=0.015)

# ---------- hopper ----------
hopper()

# ---------- side catwalks and guard rails ----------
for side in (-1,1):
    x=side*5.25
    box('Catwalk',(x,-0.45,3.25),(1.65,4.9,0.22),MAT_YEL,bevel=0.03)
    # dark center grating strip
    box('CatwalkDeck',(x,-0.45,3.39),(1.30,4.55,0.08),MAT_CHAR,bevel=0.015)
    outer=side*6.05
    for y in (-2.55,-1.2,0.2,1.55):
        beam('RailPost',(outer,y,3.35),(outer,y,4.65),0.055,MAT_YEL,10)
    beam('RailTop',(outer,-2.55,4.65),(outer,1.55,4.65),0.055,MAT_YEL,10)
    beam('RailMid',(outer,-2.55,4.03),(outer,1.55,4.03),0.05,MAT_YEL,10)
    # end rails
    for y in (-2.55,1.55):
        beam('RailEnd',(side*4.55,y,4.65),(outer,y,4.65),0.055,MAT_YEL,10)
        beam('RailEnd',(side*4.55,y,4.03),(outer,y,4.03),0.05,MAT_YEL,10)
        beam('RailPost',(side*4.55,y,3.35),(side*4.55,y,4.65),0.055,MAT_YEL,10)

# left ladder
lx=-6.15
beam('LadderRail',(lx,-2.15,0.45),(lx,-2.15,3.35),0.055,MAT_YEL,10)
beam('LadderRail',(lx,-1.45,0.45),(lx,-1.45,3.35),0.055,MAT_YEL,10)
for z in np.linspace(0.65,3.1,9):
    beam('LadderRung',(lx,-2.15,float(z)),(lx,-1.45,float(z)),0.045,MAT_YEL,10)

# hydraulics / braces
for side in (-1,1):
    beam('HydraulicBody',(side*4.25,-2.58,2.3),(side*4.25,-2.28,4.65),0.15,MAT_YEL,16)
    beam('HydraulicRod',(side*4.25,-2.26,4.55),(side*4.25,-2.08,5.35),0.08,MAT_HARD,12)

# ---------- discharge conveyor / chute ----------
# bed slopes downward toward front (-Y)
rot_x=math.radians(-17)
box('ConveyorBed',(0,-4.65,2.05),(3.45,5.35,0.34),MAT_RUB,rot=(rot_x,0,0),bevel=0.08)
# steel undertray
box('ConveyorUnder',(0,-4.60,1.82),(3.85,5.15,0.20),MAT_CHAR,rot=(rot_x,0,0),bevel=0.05)
# side guards
for x in (-1.92,1.92):
    box('ConveyorGuard',(x,-4.62,2.34),(0.20,5.15,0.86),MAT_YEL,rot=(rot_x,0,0),bevel=0.06)
# end roller
cyl('ConveyorRoller',(0,-7.15,1.28),0.42,3.25,MAT_HARD,rot=(0,math.pi/2,0),verts=24,bevel=0.04)

# front support legs for conveyor
for x in (-1.75,1.75):
    beam('ConveyorLeg',(x,-6.85,0.35),(x,-6.45,1.55),0.10,MAT_CHAR,10)
    box('ConveyorFoot',(x,-6.86,0.16),(0.6,0.6,0.16),MAT_CHAR,bevel=0.02)

# ---------- UVs + apply modifiers ----------
mesh_objs=[o for o in EXPORT if o.type=='MESH']
for o in mesh_objs:
    bpy.context.view_layer.objects.active=o
    o.select_set(True)
    # apply modifiers for deterministic glTF
    for m in list(o.modifiers):
        try:
            bpy.ops.object.modifier_apply(modifier=m.name)
        except:
            pass
    o.select_set(False)

# Smart UV project all at once
bpy.ops.object.select_all(action='DESELECT')
for o in mesh_objs:
    o.select_set(True)
bpy.context.view_layer.objects.active=mesh_objs[0]
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.025)
bpy.ops.object.mode_set(mode='OBJECT')

# Triangulate after UVs so tangent generation is valid in glTF/Roblox.
for o in mesh_objs:
    bpy.context.view_layer.objects.active=o
    o.select_set(True)
    tri=o.modifiers.new('ExportTriangulate','TRIANGULATE')
    tri.quad_method='BEAUTY'
    tri.ngon_method='BEAUTY'
    bpy.ops.object.modifier_apply(modifier=tri.name)
    o.select_set(False)

# ---------- studio floor ----------
bpy.ops.mesh.primitive_plane_add(size=60, location=(0,0,0))
floor=bpy.context.object; floor.name='PreviewFloor'
floor_mat=bpy.data.materials.new('PreviewFloorMat'); floor_mat.diffuse_color=(0.055,0.06,0.07,1); floor.data.materials.append(floor_mat)

# ---------- camera and lighting ----------
def point_camera(cam, target):
    direction=Vector(target)-cam.location
    cam.rotation_euler=direction.to_track_quat('-Z','Y').to_euler()

bpy.ops.object.camera_add(location=(15.5,-18.5,11.8))
cam=bpy.context.object; cam.data.lens=52
point_camera(cam,(0,-0.8,4.4)); scene.camera=cam

def area(name, loc, energy, size, color=(1,1,1)):
    bpy.ops.object.light_add(type='AREA', location=loc)
    l=bpy.context.object; l.name=name; l.data.energy=energy; l.data.shape='DISK'; l.data.size=size; l.data.color=color
    l.rotation_euler=(0,0,0)
    direction=Vector((0,0,4.0))-l.location
    l.rotation_euler=direction.to_track_quat('-Z','Y').to_euler()

area('Key',(7,-10,16),1800,7.5,(1.0,0.92,0.82))
area('Fill',(-11,-5,10),1100,6.0,(0.72,0.84,1.0))
area('Rim',(3,10,14),1500,6.0,(1.0,0.82,0.62))
area('Top',(-1,0,18),1000,5.0,(1.0,1.0,1.0))

# ---------- save and export ----------
blend_path=os.path.join(OUT,'industrial_scrap_shredder.blend')
preview_path=os.path.join(OUT,'industrial_scrap_shredder_preview.png')
glb_path=os.path.join(OUT,'industrial_scrap_shredder_roblox.glb')

bpy.ops.wm.save_as_mainfile(filepath=blend_path)
scene.render.filepath=preview_path
bpy.ops.render.render(write_still=True)

# export only machine meshes
bpy.ops.object.select_all(action='DESELECT')
for o in mesh_objs:
    o.select_set(True)
bpy.context.view_layer.objects.active=mesh_objs[0]
bpy.ops.export_scene.gltf(
    filepath=glb_path,
    export_format='GLB',
    use_selection=True,
    export_apply=True,
    export_texcoords=True,
    export_normals=True,
    export_tangents=True,
    export_materials='EXPORT',
    export_image_format='AUTO',
    export_yup=True,
)

# stats
tris=0
verts=0
for o in mesh_objs:
    me=o.data
    me.calc_loop_triangles()
    tris += len(me.loop_triangles)
    verts += len(me.vertices)
print('DONE')
print('objects',len(mesh_objs),'verts',verts,'tris',tris)
print('blend',blend_path)
print('glb',glb_path)
print('preview',preview_path)
