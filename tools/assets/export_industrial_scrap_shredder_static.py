import bpy
import os
import math
from array import array

SRC='/opt/roblox-assets/scrap_shredder_blender/industrial_scrap_shredder.blend'
OUT='/opt/roblox-assets/scrap_shredder_blender'
GLB=os.path.join(OUT,'industrial_scrap_shredder_static_atlas_roblox.glb')
BLEND=os.path.join(OUT,'industrial_scrap_shredder_static_atlas.blend')
ATLAS=2048

bpy.ops.wm.open_mainfile(filepath=SRC)
scene=bpy.context.scene
scene.render.engine='CYCLES'
scene.cycles.samples=1
scene.render.bake.margin=16

machine=[o for o in scene.objects if o.type=='MESH' and o.name!='PreviewFloor']
bpy.ops.object.select_all(action='DESELECT')
for o in machine: o.select_set(True)
bpy.context.view_layer.objects.active=machine[0]
bpy.ops.object.join()
obj=bpy.context.object
obj.name='IndustrialScrapShredder_Static'

# Keep below Roblox 20k triangle cap.
obj.data.calc_loop_triangles()
start=len(obj.data.loop_triangles)
if start>18500:
    dec=obj.modifiers.new('RobloxTriangleBudget','DECIMATE')
    dec.decimate_type='COLLAPSE'
    dec.ratio=18500/start
    dec.use_collapse_triangulate=True
    bpy.ops.object.modifier_apply(modifier=dec.name)
tri=obj.modifiers.new('ExportTriangulate','TRIANGULATE')
bpy.ops.object.modifier_apply(modifier=tri.name)
obj.data.calc_loop_triangles()
final_tris=len(obj.data.loop_triangles)

# Preserve original texture sampling UV explicitly before making atlas UV active.
if len(obj.data.uv_layers)==0:
    raise RuntimeError('Source mesh has no UV map')
source_uv=obj.data.uv_layers[0].name
for mat in [m for m in obj.data.materials if m and m.use_nodes]:
    nt=mat.node_tree
    uv=nt.nodes.get('AtlasBake_SourceUV') or nt.nodes.new('ShaderNodeUVMap')
    uv.name='AtlasBake_SourceUV'; uv.uv_map=source_uv
    for n in nt.nodes:
        if n.type=='TEX_IMAGE' and n.name!='AtlasBake_Target':
            if not n.inputs['Vector'].is_linked:
                nt.links.new(uv.outputs['UV'],n.inputs['Vector'])

# New atlas UV.
atlas_uv=obj.data.uv_layers.get('AtlasUV') or obj.data.uv_layers.new(name='AtlasUV')
obj.data.uv_layers.active=atlas_uv
atlas_uv.active_render=True
bpy.context.view_layer.objects.active=obj
obj.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.006)
bpy.ops.object.mode_set(mode='OBJECT')

# Helper images.
def new_img(name, noncolor=False):
    img=bpy.data.images.new(name,width=ATLAS,height=ATLAS,alpha=False,float_buffer=False)
    img.generated_color=(0,0,0,1)
    img.file_format='PNG'
    if noncolor: img.colorspace_settings.name='Non-Color'
    return img

base_img=new_img('Shredder_BaseColor')
rough_img=new_img('Shredder_Roughness',True)
metal_img=new_img('Shredder_Metallic',True)
normal_img=new_img('Shredder_Normal',True)

materials=[m for m in obj.data.materials if m and m.use_nodes]

def prepare_targets(img):
    for mat in materials:
        nt=mat.node_tree
        t=nt.nodes.get('AtlasBake_Target') or nt.nodes.new('ShaderNodeTexImage')
        t.name='AtlasBake_Target'; t.image=img
        nt.nodes.active=t
        t.select=True

def bake_socket_to_emit(socket_name, img):
    states=[]
    prepare_targets(img)
    for mat in materials:
        nt=mat.node_tree
        out=next((n for n in nt.nodes if n.type=='OUTPUT_MATERIAL'),None)
        bsdf=next((n for n in nt.nodes if n.type=='BSDF_PRINCIPLED'),None)
        if not out or not bsdf: continue
        old_links=list(out.inputs['Surface'].links)
        emit=nt.nodes.new('ShaderNodeEmission'); emit.name='AtlasBake_Emission'
        sock=bsdf.inputs[socket_name]
        if sock.is_linked:
            nt.links.new(sock.links[0].from_socket,emit.inputs['Color'])
        else:
            v=sock.default_value
            if hasattr(v,'__len__'):
                emit.inputs['Color'].default_value=tuple(v[:4])
            else:
                emit.inputs['Color'].default_value=(float(v),float(v),float(v),1)
        for link in old_links: nt.links.remove(link)
        nt.links.new(emit.outputs['Emission'],out.inputs['Surface'])
        states.append((mat,out,bsdf,emit))
    bpy.ops.object.bake(type='EMIT',use_clear=True)
    for mat,out,bsdf,emit in states:
        nt=mat.node_tree
        for link in list(out.inputs['Surface'].links): nt.links.remove(link)
        nt.links.new(bsdf.outputs['BSDF'],out.inputs['Surface'])
        nt.nodes.remove(emit)

bake_socket_to_emit('Base Color',base_img)
bake_socket_to_emit('Roughness',rough_img)
bake_socket_to_emit('Metallic',metal_img)

prepare_targets(normal_img)
bpy.ops.object.bake(type='NORMAL',normal_space='TANGENT',use_clear=True)

# Save baked source images.
for img,fn in [
    (base_img,'shredder_atlas_basecolor.png'),
    (rough_img,'shredder_atlas_roughness.png'),
    (metal_img,'shredder_atlas_metallic.png'),
    (normal_img,'shredder_atlas_normal.png')]:
    img.filepath_raw=os.path.join(OUT,fn); img.save()

# Build packed glTF metallic-roughness image: R=1, G=roughness, B=metallic.
rough=list(rough_img.pixels[:])
metal=list(metal_img.pixels[:])
count=ATLAS*ATLAS
mr=array('f',[0.0])*(count*4)
for i in range(count):
    j=i*4
    mr[j]=1.0
    mr[j+1]=rough[j]
    mr[j+2]=metal[j]
    mr[j+3]=1.0
mr_img=bpy.data.images.new('Shredder_MetallicRoughness',width=ATLAS,height=ATLAS,alpha=False,float_buffer=False)
mr_img.colorspace_settings.name='Non-Color'
mr_img.pixels.foreach_set(mr)
mr_img.filepath_raw=os.path.join(OUT,'shredder_atlas_metallicroughness.png'); mr_img.file_format='PNG'; mr_img.save()

# Collapse to one PBR material and one glTF primitive.
final=bpy.data.materials.new('IndustrialScrapShredder_Atlas')
final.use_nodes=True
nt=final.node_tree
bsdf=nt.nodes.get('Principled BSDF')
bsdf.inputs['Metallic'].default_value=1.0
bsdf.inputs['Roughness'].default_value=1.0
uv=nt.nodes.new('ShaderNodeUVMap'); uv.uv_map='AtlasUV'
base=nt.nodes.new('ShaderNodeTexImage'); base.image=base_img
mrn=nt.nodes.new('ShaderNodeTexImage'); mrn.image=mr_img
norm=nt.nodes.new('ShaderNodeTexImage'); norm.image=normal_img
sep=nt.nodes.new('ShaderNodeSeparateColor')
nm=nt.nodes.new('ShaderNodeNormalMap'); nm.inputs['Strength'].default_value=0.45
nt.links.new(uv.outputs['UV'],base.inputs['Vector'])
nt.links.new(uv.outputs['UV'],mrn.inputs['Vector'])
nt.links.new(uv.outputs['UV'],norm.inputs['Vector'])
nt.links.new(base.outputs['Color'],bsdf.inputs['Base Color'])
nt.links.new(mrn.outputs['Color'],sep.inputs['Color'])
nt.links.new(sep.outputs['Green'],bsdf.inputs['Roughness'])
nt.links.new(sep.outputs['Blue'],bsdf.inputs['Metallic'])
nt.links.new(norm.outputs['Color'],nm.inputs['Color'])
nt.links.new(nm.outputs['Normal'],bsdf.inputs['Normal'])

obj.data.materials.clear()
obj.data.materials.append(final)
for p in obj.data.polygons: p.material_index=0

# Pack atlas images in .blend and export single mesh + single material.
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=BLEND)
bpy.ops.object.select_all(action='DESELECT'); obj.select_set(True); bpy.context.view_layer.objects.active=obj
bpy.ops.export_scene.gltf(
    filepath=GLB, export_format='GLB', use_selection=True, export_apply=True,
    export_texcoords=True, export_normals=True, export_tangents=True,
    export_materials='EXPORT', export_image_format='AUTO', export_yup=True,
)
print('START_TRIS',start)
print('FINAL_TRIS',final_tris)
print('MATERIALS',len(obj.data.materials))
print('GLB',GLB)
