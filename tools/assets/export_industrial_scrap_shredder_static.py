import bpy, os, math
from array import array
from mathutils import Vector

SRC="/opt/roblox-assets/scrap_shredder_blender/industrial_scrap_shredder.blend"
OUT="/opt/roblox-assets/scrap_shredder_blender"
os.makedirs(OUT, exist_ok=True)
GLB=os.path.join(OUT,"industrial_scrap_shredder_static_atlas_roblox.glb")
BLEND=os.path.join(OUT,"industrial_scrap_shredder_static_atlas.blend")
PREVIEW=os.path.join(OUT,"industrial_scrap_shredder_preview.png")
ATLAS=1024
TARGET_TRIS=4800

bpy.ops.wm.open_mainfile(filepath=SRC)
scene=bpy.context.scene
machine=[o for o in scene.objects if o.type=="MESH" and o.name not in {"PreviewFloor","Backdrop"}]
# Remove preview cameras/lights/backdrop/floor; rebuild after final mesh.
for o in list(scene.objects):
    if o not in machine:
        bpy.data.objects.remove(o, do_unlink=True)

bpy.ops.object.select_all(action="DESELECT")
for o in machine: o.select_set(True)
bpy.context.view_layer.objects.active=machine[0]
bpy.ops.object.join()
obj=bpy.context.object
obj.name="IndustrialScrapShredder"
obj.data.calc_loop_triangles(); start=len(obj.data.loop_triangles)

# Weld accidental coplanar duplicates before decimation.
bpy.context.view_layer.objects.active=obj
obj.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.remove_doubles(threshold=0.0005)
bpy.ops.object.mode_set(mode="OBJECT")
obj.data.calc_loop_triangles(); welded=len(obj.data.loop_triangles)

if welded > TARGET_TRIS:
    dec=obj.modifiers.new("RobloxTriangleBudget","DECIMATE")
    dec.decimate_type="COLLAPSE"
    dec.ratio=TARGET_TRIS/welded
    dec.use_collapse_triangulate=True
    bpy.ops.object.modifier_apply(modifier=dec.name)
tri=obj.modifiers.new("ExportTriangulate","TRIANGULATE")
tri.quad_method="BEAUTY"; tri.ngon_method="BEAUTY"
bpy.ops.object.modifier_apply(modifier=tri.name)
obj.data.calc_loop_triangles(); final_tris=len(obj.data.loop_triangles)

# Single atlas UV.
if len(obj.data.uv_layers)==0:
    obj.data.uv_layers.new(name="SourceUV")
source_uv=obj.data.uv_layers[0].name
for mat in [m for m in obj.data.materials if m and m.use_nodes]:
    nt=mat.node_tree
    uv=nt.nodes.get("AtlasBake_SourceUV") or nt.nodes.new("ShaderNodeUVMap")
    uv.name="AtlasBake_SourceUV"; uv.uv_map=source_uv
    for n in nt.nodes:
        if n.type=="TEX_IMAGE" and n.name!="AtlasBake_Target" and not n.inputs["Vector"].is_linked:
            nt.links.new(uv.outputs["UV"],n.inputs["Vector"])

atlas_uv=obj.data.uv_layers.get("AtlasUV") or obj.data.uv_layers.new(name="AtlasUV")
obj.data.uv_layers.active=atlas_uv; atlas_uv.active_render=True
bpy.context.view_layer.objects.active=obj
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.008)
bpy.ops.object.mode_set(mode="OBJECT")

scene.render.engine="CYCLES"
scene.cycles.samples=1
scene.render.bake.margin=8

def new_img(name, noncolor=False):
    img=bpy.data.images.new(name,width=ATLAS,height=ATLAS,alpha=False,float_buffer=False)
    img.generated_color=(0,0,0,1); img.file_format="PNG"
    if noncolor: img.colorspace_settings.name="Non-Color"
    return img

base_img=new_img("Shredder_BaseColor")
rough_img=new_img("Shredder_Roughness",True)
metal_img=new_img("Shredder_Metallic",True)
normal_img=new_img("Shredder_Normal",True)
materials=[m for m in obj.data.materials if m and m.use_nodes]

def prepare(img):
    for mat in materials:
        nt=mat.node_tree
        t=nt.nodes.get("AtlasBake_Target") or nt.nodes.new("ShaderNodeTexImage")
        t.name="AtlasBake_Target"; t.image=img; nt.nodes.active=t; t.select=True

def bake_socket(sock_name,img):
    states=[]; prepare(img)
    for mat in materials:
        nt=mat.node_tree
        out=next((n for n in nt.nodes if n.type=="OUTPUT_MATERIAL"),None)
        bsdf=next((n for n in nt.nodes if n.type=="BSDF_PRINCIPLED"),None)
        if not out or not bsdf: continue
        old=list(out.inputs["Surface"].links)
        emit=nt.nodes.new("ShaderNodeEmission")
        sock=bsdf.inputs[sock_name]
        if sock.is_linked: nt.links.new(sock.links[0].from_socket,emit.inputs["Color"])
        else:
            v=sock.default_value
            emit.inputs["Color"].default_value=tuple(v[:4]) if hasattr(v,"__len__") else (float(v),)*3+(1,)
        for link in old: nt.links.remove(link)
        nt.links.new(emit.outputs["Emission"],out.inputs["Surface"])
        states.append((mat,out,bsdf,emit))
    bpy.ops.object.bake(type="EMIT",use_clear=True)
    for mat,out,bsdf,emit in states:
        nt=mat.node_tree
        for link in list(out.inputs["Surface"].links): nt.links.remove(link)
        nt.links.new(bsdf.outputs["BSDF"],out.inputs["Surface"])
        nt.nodes.remove(emit)

bake_socket("Base Color",base_img)
bake_socket("Roughness",rough_img)
bake_socket("Metallic",metal_img)
prepare(normal_img)
bpy.ops.object.bake(type="NORMAL",normal_space="TANGENT",use_clear=True)

for img,fn in [(base_img,"basecolor.png"),(rough_img,"roughness.png"),(metal_img,"metallic.png"),(normal_img,"normal.png")]:
    img.filepath_raw=os.path.join(OUT,fn); img.save()

# Pack glTF metallic/roughness.
rough=list(rough_img.pixels[:]); metal=list(metal_img.pixels[:]); count=ATLAS*ATLAS
mr=array("f",[0.0])*(count*4)
for i in range(count):
    j=i*4; mr[j]=1.0; mr[j+1]=rough[j]; mr[j+2]=metal[j]; mr[j+3]=1.0
mr_img=bpy.data.images.new("Shredder_MetallicRoughness",width=ATLAS,height=ATLAS,alpha=False,float_buffer=False)
mr_img.colorspace_settings.name="Non-Color"; mr_img.pixels.foreach_set(mr)
mr_img.filepath_raw=os.path.join(OUT,"metallicroughness.png"); mr_img.file_format="PNG"; mr_img.save()

final=bpy.data.materials.new("IndustrialScrapShredder_Atlas"); final.use_nodes=True
nt=final.node_tree; bsdf=nt.nodes.get("Principled BSDF")
uv=nt.nodes.new("ShaderNodeUVMap"); uv.uv_map="AtlasUV"
base=nt.nodes.new("ShaderNodeTexImage"); base.image=base_img
mrn=nt.nodes.new("ShaderNodeTexImage"); mrn.image=mr_img
norm=nt.nodes.new("ShaderNodeTexImage"); norm.image=normal_img
sep=nt.nodes.new("ShaderNodeSeparateColor"); nm=nt.nodes.new("ShaderNodeNormalMap"); nm.inputs["Strength"].default_value=0.55
nt.links.new(uv.outputs["UV"],base.inputs["Vector"]); nt.links.new(base.outputs["Color"],bsdf.inputs["Base Color"])
nt.links.new(uv.outputs["UV"],mrn.inputs["Vector"]); nt.links.new(mrn.outputs["Color"],sep.inputs["Color"])
nt.links.new(sep.outputs["Green"],bsdf.inputs["Roughness"]); nt.links.new(sep.outputs["Blue"],bsdf.inputs["Metallic"])
nt.links.new(uv.outputs["UV"],norm.inputs["Vector"]); nt.links.new(norm.outputs["Color"],nm.inputs["Color"]); nt.links.new(nm.outputs["Normal"],bsdf.inputs["Normal"])
obj.data.materials.clear(); obj.data.materials.append(final)
for p in obj.data.polygons: p.material_index=0

# Put pivot at bottom center, object origin at world x/z center and floor y equivalent (Blender Z-up here).
# Geometry remains in world position; set origin cursor to bottom center without changing visual.
world=[obj.matrix_world @ Vector(c) for c in obj.bound_box]
minx,maxx=min(p.x for p in world),max(p.x for p in world)
miny,maxy=min(p.y for p in world),max(p.y for p in world)
minz,maxz=min(p.z for p in world),max(p.z for p in world)
scene.cursor.location=((minx+maxx)/2,(miny+maxy)/2,minz)
bpy.context.view_layer.objects.active=obj; obj.select_set(True)
bpy.ops.object.origin_set(type="ORIGIN_CURSOR",center="MEDIAN")

bpy.ops.file.pack_all(); bpy.ops.wm.save_as_mainfile(filepath=BLEND)
# Export final single mesh/material.
bpy.ops.object.select_all(action="DESELECT"); obj.select_set(True); bpy.context.view_layer.objects.active=obj
bpy.ops.export_scene.gltf(filepath=GLB,export_format="GLB",use_selection=True,export_apply=True,export_texcoords=True,export_normals=True,export_tangents=True,export_materials="EXPORT",export_image_format="AUTO",export_yup=True)

# Preview final decimated mesh with material.
scene.render.engine="BLENDER_EEVEE"; scene.render.resolution_x=900; scene.render.resolution_y=900; scene.render.resolution_percentage=100
floor_mat=bpy.data.materials.new("PreviewFloorMat"); floor_mat.diffuse_color=(0.05,0.055,0.065,1)
bpy.ops.mesh.primitive_plane_add(size=28,location=(0,0,minz-0.02)); floor=bpy.context.object; floor.data.materials.append(floor_mat)

def point(o,target): o.rotation_euler=(Vector(target)-o.location).to_track_quat("-Z","Y").to_euler()
bpy.ops.object.camera_add(location=(15.5,-18.0,11.5)); cam=bpy.context.object; cam.data.lens=55; point(cam,(0,0,4.4)); scene.camera=cam
for loc,energy,size,color in [((8,-10,15),1500,7,(1,.91,.8)),((-10,-5,9),850,6,(.7,.82,1)),((4,8,13),1250,6,(1,.76,.55)),((-1,0,16),850,5,(1,1,1))]:
    bpy.ops.object.light_add(type="AREA",location=loc); l=bpy.context.object; l.data.energy=energy; l.data.shape="DISK"; l.data.size=size; l.data.color=color; point(l,(0,0,4.4))
scene.world.color=(0.018,0.022,0.028); scene.render.filepath=PREVIEW; bpy.ops.render.render(write_still=True)

print("FINAL_START_TRIS",start); print("FINAL_WELDED_TRIS",welded); print("FINAL_TRIS",final_tris); print("FINAL_MATERIALS",len(obj.data.materials)); print("FINAL_MESH_OBJECTS",1); print("FINAL_GLB",GLB); print("FINAL_BLEND",BLEND); print("FINAL_PREVIEW",PREVIEW)
