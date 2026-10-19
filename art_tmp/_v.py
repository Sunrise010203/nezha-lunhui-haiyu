
import bpy, math, os, json
import numpy as np
SRC = r"E:\godot_game_by_fable\001\art\models\nezha_opt.glb"
OUT = r"E:\godot_game_by_fable\art_tmp"
def log(t, **k): print("@@V " + json.dumps({"t": t, **k}, ensure_ascii=False), flush=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
sc = bpy.context.scene
sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = 2
obj = [o for o in bpy.data.objects if o.type == 'MESH' and len(o.data.vertices) > 1000][0]
bpy.ops.object.select_all(action='DESELECT')
obj.select_set(True); bpy.context.view_layer.objects.active = obj

def make_img(name, cs):
    img = bpy.data.images.new(name, 512, 512, alpha=False, float_buffer=False)
    img.colorspace_settings.name = cs
    return img

def bake_into(img):
    m = bpy.data.materials.new("bm_" + img.name); m.use_nodes = True
    nt = m.node_tree; nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission"); em.inputs[0].default_value = (0.2, 0.6, 1.0, 1)
    nt.links.new(em.outputs[0], out.inputs[0])
    tex = nt.nodes.new("ShaderNodeTexImage"); tex.image = img; tex.name = "BAKETARGET"
    for n in nt.nodes: n.select = False
    tex.select = True; nt.nodes.active = tex
    for i in range(len(obj.material_slots)):
        obj.material_slots[i].material = m
    obj.active_material_index = 0
    bpy.ops.object.bake(type='EMIT', margin=16, use_clear=True)
    px = np.zeros(512*512*4, dtype=np.float32)
    img.pixels.foreach_get(px)
    px = px.reshape(-1, 4)
    return [round(float(v),3) for v in px[:,:3].mean(0)]

a = make_img("A", 'sRGB')
log("bakeA", mean=bake_into(a))
a.filepath_raw = os.path.join(OUT, "_A.png"); a.file_format = 'PNG'; a.save()

b = make_img("B", 'sRGB')
log("bakeB", mean=bake_into(b))
b.colorspace_settings.name = 'Non-Color'
px = np.zeros(512*512*4, dtype=np.float32); b.pixels.foreach_get(px)
log("after_cs_change", mean=[round(float(v),4) for v in px.reshape(-1,4)[:,:3].mean(0)])
b.filepath_raw = os.path.join(OUT, "_B.png"); b.file_format = 'PNG'; b.save()

c = make_img("C", 'sRGB')
log("bakeC", mean=bake_into(c))
c.filepath_raw = os.path.join(OUT, "_C.png"); c.file_format = 'PNG'
c.colorspace_settings.name = 'Non-Color'
c.save()
log("sizes", A=os.path.getsize(os.path.join(OUT,"_A.png")), B=os.path.getsize(os.path.join(OUT,"_B.png")), C=os.path.getsize(os.path.join(OUT,"_C.png")))
