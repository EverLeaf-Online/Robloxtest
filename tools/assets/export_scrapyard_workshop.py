"""Blender 4: export modular GLBs and render the exact architecture blueprint.
Usage: blender -b -t 2 --python tools/assets/export_scrapyard_workshop.py
Geometry exports are the new kit only; preview optionally adds existing core meshes.
"""
import bpy, json, math, hashlib
from pathlib import Path
from mathutils import Vector, Matrix, Euler
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/"assets/factory/scrapyard_workshop"
data=json.loads((OUT/"scene.json").read_text())
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
M={}
groups={}
convert=Matrix(((1,0,0),(0,0,-1),(0,1,0)))
def mat(rgb,kind):
    key=tuple(rgb)+(kind,)
    if key not in M:
        m=bpy.data.materials.new(kind+"_"+"_".join(map(str,rgb)))
        m.diffuse_color=(*[c/255 for c in rgb],1)
        m.use_nodes=True
        n=m.node_tree.nodes.get("Principled BSDF")
        n.inputs["Base Color"].default_value=m.diffuse_color
        n.inputs["Metallic"].default_value=.35 if kind=="Metal" else 0
        n.inputs["Roughness"].default_value=.62
        if kind=="Neon":
            n.inputs["Emission Color"].default_value=m.diffuse_color
            n.inputs["Emission Strength"].default_value=1.2
        M[key]=m
    return M[key]
for p in data["parts"]:
    size=p["size"]
    if p["shape"]=="Cylinder":
        bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=.5,depth=1)
        ob=bpy.context.object
        # Roblox cylinder length lies along X, Blender primitive length along Z.
        for v in ob.data.vertices:
            x,y,z=v.co
            v.co=(z*size[0],x*size[1],y*size[2])
    else:
        bpy.ops.mesh.primitive_cube_add(size=1)
        ob=bpy.context.object
        for v in ob.data.vertices:
            v.co=Vector([v.co[i]*size[i] for i in range(3)])
    rotation=Euler([math.radians(a) for a in p["rotation"]],"XYZ").to_matrix()
    for v in ob.data.vertices: v.co=convert @ rotation @ v.co
    ob.location=convert @ Vector(p["pos"])
    ob.name=p["group"]+"_"+p["name"]
    ob.data.materials.append(mat(p["color"],p["material"]))
    groups.setdefault(p["group"],[]).append(ob)
    if p.get("text"):
        curve=bpy.data.curves.new("SignText","FONT")
        curve.body=p["text"]; curve.align_x="CENTER"; curve.align_y="CENTER"
        curve.size=min(size[1]*.5,size[0]/max(1,len(p["text"]))*1.25)
        obj=bpy.data.objects.new("Label_"+p["name"],curve)
        bpy.context.collection.objects.link(obj)
        obj.location=convert @ Vector([p["pos"][0],p["pos"][1],p["pos"][2]-size[2]/2-.03])
        obj.rotation_euler=(math.pi/2,0,math.pi)
        # Camera from negative Roblox Z sees the front of the signs.
        curve.materials.append(mat([246,236,202],"SmoothPlastic"))
        # Labels are rendered by SurfaceGui at runtime; excluded from mesh exports.
manifest=[]
meshdir=OUT/"meshes"
meshdir.mkdir(exist_ok=True)
for name,objects in groups.items():
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objects: ob.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.object.join()
    ob=bpy.context.object
    # Export centered ground-level pivots. The JSON carries placement in the plot.
    coords=[ob.matrix_world @ v.co for v in ob.data.vertices]
    low=Vector([min(v[i] for v in coords) for i in range(3)])
    high=Vector([max(v[i] for v in coords) for i in range(3)])
    pivot=Vector(((low.x+high.x)/2,(low.y+high.y)/2,low.z))
    bpy.context.scene.cursor.location=pivot
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    old=ob.location.copy()
    ob.location=Vector((0,0,0))
    path=meshdir/(name+".glb")
    bpy.ops.export_scene.gltf(filepath=str(path),export_format="GLB",use_selection=True,
                              export_yup=True,export_apply=True)
    ob.location=old
    tris=sum(len(p.vertices)-2 for p in ob.data.polygons)
    assert tris<=5000,(name,tris)
    manifest.append(dict(name=name,file="meshes/"+path.name,triangles=tris,
                         pivot="BottomCenter",placementRoblox=[pivot.x,pivot.z,-pivot.y],
                         bytes=path.stat().st_size,sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
# Context meshes already authored for this game. Optional, never included in new GLB exports.
context=[]
existing=Path("/opt/scrap-bot-factory-assets/optimized")
for name,pos,maximum,angle in [
    ("magnetic_sorting_conveyor",(-27,0,20),24,0),
    ("hydraulic_scrap_baler",(55,0,44),15,0),
    ("bot_assembler_station",(38,.5,20),12,0),
    ("infeed_conveyor_8m",(-68,0,20),24,90),
    ("outfeed_conveyor_6m",(54,0,20),22,90),
    ("scrap_pile_medium",(-90,0,40),12,0),
    ("large_scrap_hopper",(-100,0,10),10,0),
]:
    f=existing/(name+"_optimized.glb")
    if not f.exists(): continue
    before=set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(f))
    obs=[o for o in set(bpy.data.objects)-before if o.type=="MESH"]
    if not obs: continue
    bpy.ops.object.select_all(action="DESELECT")
    for ob in obs: ob.select_set(True)
    bpy.context.view_layer.objects.active=obs[0]
    bpy.ops.object.join(); ob=bpy.context.object
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    coords=[ob.matrix_world @ v.co for v in ob.data.vertices]
    low=Vector([min(v[i] for v in coords) for i in range(3)])
    high=Vector([max(v[i] for v in coords) for i in range(3)])
    pivot=Vector(((low.x+high.x)/2,(low.y+high.y)/2,low.z))
    bpy.context.scene.cursor.location=pivot
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    scale=maximum/max(high-low)
    ob.scale=(scale,)*3
    ob.location=convert @ Vector(pos)
    ob.rotation_euler.z=math.radians(angle)
    context.append(name)
scene=bpy.context.scene
scene.render.engine="CYCLES"
scene.cycles.device="CPU"
scene.cycles.samples=24
scene.cycles.use_denoising=False
scene.render.resolution_x=1400
scene.render.resolution_y=950
scene.render.resolution_percentage=100
scene.world.color=(.22,.26,.3)
scene.view_settings.view_transform="AgX"
def area(name,loc,power,size):
    light=bpy.data.lights.new(name,"AREA"); light.energy=power; light.shape="DISK"; light.size=size
    ob=bpy.data.objects.new(name,light); bpy.context.collection.objects.link(ob)
    ob.location=loc
    ob.rotation_euler=(Vector((0,0,0))-ob.location).to_track_quat("-Z","Y").to_euler()
area("Warm key",(-80,100,180),180000,130)
area("Cool fill",(100,0,140),100000,100)
sun=bpy.data.lights.new("Daylight","SUN"); sun.energy=2
ob=bpy.data.objects.new("Daylight",sun); bpy.context.collection.objects.link(ob)
ob.rotation_euler=(.4,-.5,-.3)
camera=bpy.data.cameras.new("Camera")
cam=bpy.data.objects.new("Camera",camera); bpy.context.collection.objects.link(cam); scene.camera=cam
camera.type="ORTHO"
for name,loc,target,scale in [
    ("workshop-overview",(-210,260,215),(0,-5,2),280),
    ("workshop-player-view",(-150,140,85),(-10,-18,5),210),
]:
    cam.location=loc; cam.rotation_euler=(Vector(target)-cam.location).to_track_quat("-Z","Y").to_euler()
    camera.ortho_scale=scale
    scene.render.filepath=str(OUT/(name+".png"))
    bpy.ops.render.render(write_still=True)
    scene.render.image_settings.file_format="JPEG"
    scene.render.image_settings.quality=88
    bpy.data.images["Render Result"].save_render(str(OUT/(name+".jpg")),scene=scene)
    scene.render.image_settings.file_format="PNG"
report=dict(schema=1,source="Original deterministic geometry; no third-party assets",runtime="Native anchored Roblox parts from the same blueprint; GLBs are optional import sources",
            collision="Explicit native primitives only",partCount=len(data["parts"]),
            assets=manifest,previewContextMeshes=context,
            previewLimit="Architecture review with selected existing machinery; not a Roblox gameplay screenshot.")
(OUT/"manifest.json").write_text(json.dumps(report,indent=2)+"\n")
print("WORKSHOP_EXPORT_COMPLETE",len(manifest),sum(m["triangles"] for m in manifest))
