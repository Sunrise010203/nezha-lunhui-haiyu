import bpy
SRC = r"E:\godot_game_by_fable\art_tmp\nezha_lit.glb"
OUT = r"E:\godot_game_by_fable\art_tmp\nezha_bake\nezha_silkmask.png"
RES = 2048

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
obj = None
for o in bpy.data.objects:
    if o.type == 'MESH' and len(o.data.polygons) > 1000:
        obj = o
        break
for o in list(bpy.data.objects):
    if o.type == 'MESH' and o is not obj:
        bpy.data.objects.remove(o, do_unlink=True)

img = bpy.data.images.new("silkmask", width=RES, height=RES, alpha=False)
img.colorspace_settings.name = 'Non-Color'

# 材质槽 1（HuntianLing_Red）就是混天绫；整棵树换成纯 Emission，烘出几何级 mask
for i, mat in enumerate(obj.data.materials):
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new('ShaderNodeOutputMaterial')
    em = nt.nodes.new('ShaderNodeEmission')
    em.inputs['Color'].default_value = (1.0, 1.0, 1.0, 1.0) if i == 1 else (0.0, 0.0, 0.0, 1.0)
    tex = nt.nodes.new('ShaderNodeTexImage')
    tex.image = img
    tex.name = 'BAKETARGET'
    nt.nodes.active = tex
    nt.links.new(em.outputs['Emission'], out.inputs['Surface'])

sc = bpy.context.scene
sc.render.engine = 'CYCLES'
sc.cycles.device = 'CPU'
sc.cycles.samples = 1
sc.render.bake.margin = 8
sc.render.bake.use_selected_to_active = False
bpy.ops.object.select_all(action='DESELECT')
obj.select_set(True)
bpy.context.view_layer.objects.active = obj
bpy.ops.object.bake(type='EMIT')
img.filepath_raw = OUT
img.file_format = 'PNG'
img.save()
print("SAVED", OUT)
