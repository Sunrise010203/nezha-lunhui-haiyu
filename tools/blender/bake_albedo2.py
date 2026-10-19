import bpy
SRC = r"E:\godot_game_by_fable\art_tmp\nezha_lit.glb"
OUT = r"E:\godot_game_by_fable\art_tmp\nezha_bake\nezha_albedo.png"
RES = 2048

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)

obj = None
for o in bpy.data.objects:
    if o.type == 'MESH' and len(o.data.polygons) > 1000:
        obj = o
        break
if obj is None:
    raise RuntimeError("no mesh")
for o in list(bpy.data.objects):
    if o.type == 'MESH' and o is not obj:
        bpy.data.objects.remove(o, do_unlink=True)
print("OBJ", obj.name, len(obj.data.polygons), [m.name for m in obj.data.materials])

img = bpy.data.images.new("albedo2", width=RES, height=RES, alpha=False)
img.colorspace_settings.name = 'sRGB'

for mat in obj.data.materials:
    nt = mat.node_tree
    node = nt.nodes.new('ShaderNodeTexImage')
    node.image = img
    node.name = 'BAKETARGET'
    node.location = (600, 600)
    nt.nodes.active = node

sc = bpy.context.scene
sc.render.engine = 'CYCLES'
sc.cycles.device = 'CPU'
sc.cycles.samples = 4
sc.render.bake.margin = 8
sc.render.bake.use_selected_to_active = False
sc.render.bake.use_pass_direct = False
sc.render.bake.use_pass_indirect = False
sc.render.bake.use_pass_color = True

bpy.ops.object.select_all(action='DESELECT')
obj.select_set(True)
bpy.context.view_layer.objects.active = obj

bpy.ops.object.bake(type='DIFFUSE')
px = list(img.pixels[:8])
print("PIX", px)
img.filepath_raw = OUT
img.file_format = 'PNG'
img.save()
print("SAVED", OUT)
