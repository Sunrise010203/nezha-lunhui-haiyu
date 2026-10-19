
import bpy, math, os, json
import numpy as np
SRC = r"E:\godot_game_by_fable\001\art\models\nezha_opt.glb"
def log(t, **k): print("@@U " + json.dumps({"t": t, **k}, ensure_ascii=False), flush=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
sc = bpy.context.scene
sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = 2
obj = [o for o in bpy.data.objects if o.type == 'MESH' and len(o.data.vertices) > 1000][0]
me = obj.data
for o in list(bpy.data.objects):
    if o.type == 'MESH' and o is not obj:
        bpy.data.objects.remove(o, do_unlink=True)
bpy.ops.object.select_all(action='DESELECT')
obj.select_set(True)
bpy.context.view_layer.objects.active = obj

for layer in list(me.uv_layers):
    me.uv_layers.remove(layer)
me.uv_layers.new(name="UVMap")
log("after_new", active=me.uv_layers.active.name if me.uv_layers.active else None,
    n=len(me.uv_layers))

bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(angle_limit=math.radians(66.0), island_margin=0.002, correct_aspect=True)
bpy.ops.object.mode_set(mode='OBJECT')
log("after_smart", active=me.uv_layers.active.name if me.uv_layers.active else None,
    active_index=me.uv_layers.active_index)

img = bpy.data.images.new("t2", 512, 512, alpha=False, float_buffer=False)
m = bpy.data.materials.new("bm2"); m.use_nodes = True
nt = m.node_tree; nt.nodes.clear()
out = nt.nodes.new("ShaderNodeOutputMaterial")
em = nt.nodes.new("ShaderNodeEmission"); em.inputs[0].default_value = (0.2, 0.6, 1.0, 1)
nt.links.new(em.outputs[0], out.inputs[0])
tex = nt.nodes.new("ShaderNodeTexImage"); tex.image = img; tex.name = "BAKETARGET"
for n in nt.nodes: n.select = False
tex.select = True
nt.nodes.active = tex
for i in range(len(obj.material_slots)):
    obj.material_slots[i].material = m
obj.active_material_index = 0
bpy.ops.object.bake(type='EMIT', margin=4, use_clear=True)
px = np.zeros(512*512*4, dtype=np.float32)
img.pixels.foreach_get(px)
px = px.reshape(-1, 4)
log("bake", mean=[round(float(v),3) for v in px[:,:3].mean(0)], max=round(float(px[:,:3].max()),3),
    covered=round(float((px[:,0] > 0.05).mean()), 4))