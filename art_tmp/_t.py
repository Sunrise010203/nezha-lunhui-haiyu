
import bpy, os, json
import numpy as np
SRC = r"E:\godot_game_by_fable\001\art\models\nezha_opt.glb"
def log(t, **k): print("@@T " + json.dumps({"t": t, **k}, ensure_ascii=False), flush=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
sc = bpy.context.scene
sc.render.engine = 'CYCLES'
sc.cycles.device = 'CPU'
sc.cycles.samples = 4
obj = [o for o in bpy.data.objects if o.type == 'MESH' and len(o.data.vertices) > 1000][0]
log("obj", name=obj.name, sel=obj.select_get(), hide=obj.hide_render, active=bpy.context.view_layer.objects.active.name)
log("uvs", active=obj.data.uv_layers.active.name if obj.data.uv_layers.active else None,
    render_index=obj.data.uv_layers.active_render.name if getattr(obj.data.uv_layers, "active_render", None) else None)
log("vis", v=obj.visible_get())

bpy.ops.object.select_all(action='DESELECT')
obj.select_set(True)
bpy.context.view_layer.objects.active = obj

img = bpy.data.images.new("t", 256, 256, alpha=False, float_buffer=False)
m = bpy.data.materials.new("bm"); m.use_nodes = True
nt = m.node_tree; nt.nodes.clear()
out = nt.nodes.new("ShaderNodeOutputMaterial")
em = nt.nodes.new("ShaderNodeEmission"); em.inputs[0].default_value = (1, 0, 0, 1)
nt.links.new(em.outputs[0], out.inputs[0])
tex = nt.nodes.new("ShaderNodeTexImage"); tex.image = img
nt.nodes.active = tex
for n in nt.nodes: n.select = False
tex.select = True
for i in range(len(obj.material_slots)):
    obj.material_slots[i].material = m
    obj.active_material_index = i
obj.active_material_index = 0

bpy.ops.object.bake(type='EMIT', margin=4, use_clear=True)
px = np.zeros(256*256*4, dtype=np.float32)
img.pixels.foreach_get(px)
px = px.reshape(-1, 4)
log("after_bake", mean=[round(float(v),3) for v in px[:,:3].mean(0)], max=round(float(px[:,:3].max()),3),
    covered=round(float((px[:,0] > 0.5).mean()), 4))
img.filepath_raw = r"E:\godot_game_by_fable\art_tmp\_t.png"
img.file_format = 'PNG'
img.save()
log("saved", size=os.path.getsize(r"E:\godot_game_by_fable\art_tmp\_t.png"))
