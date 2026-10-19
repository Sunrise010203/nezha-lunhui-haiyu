
import bpy, sys, os, json, math
import numpy as np

SRC = r"E:\godot_game_by_fable\001\art\models\nezha_opt.glb"
OUT = r"E:\godot_game_by_fable\art_tmp\nezha_bake"
EXPORT = r"E:\godot_game_by_fable\art_tmp\nezha_lit.glb"
RES = 2048
MARGIN = 4
os.makedirs(OUT, exist_ok=True)

def log(tag, **kw):
    print("@@B " + json.dumps({"tag": tag, **kw}, ensure_ascii=False), flush=True)

def new_img(name, cs):
    img = bpy.data.images.new(name, RES, RES, alpha=False, float_buffer=False)
    img.colorspace_settings.name = cs
    return img

def save_img(img, fname, cs):
    # NOTE: never touch colorspace_settings after baking - it wipes the buffer.
    p = os.path.join(OUT, fname)
    img.filepath_raw = p
    img.file_format = 'PNG'
    img.save()
    log("saved", file=fname, cs=img.colorspace_settings.name)
    return p

def bake_mat(tag):
    m = bpy.data.materials.new(tag)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs[0], out.inputs["Surface"])
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.name = "BAKETARGET"
    for nd in nt.nodes:
        nd.select = False
    tex.select = True
    nt.nodes.active = tex
    return m

def out_node(m):
    return [n for n in m.node_tree.nodes if n.type == 'OUTPUT_MATERIAL'][0]

def target(m):
    return m.node_tree.nodes["BAKETARGET"]

def use_emit(m, socket):
    nt = m.node_tree
    em = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(socket, em.inputs["Color"])
    nt.links.new(em.outputs[0], out_node(m).inputs["Surface"])

def use_const(m, rgba):
    nt = m.node_tree
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = rgba
    nt.links.new(em.outputs[0], out_node(m).inputs["Surface"])

def new_pair():
    return [bake_mat("BK0"), bake_mat("BK1")]

def do_bake(img, mats, slots, btype, samples):
    obj = OBJ
    bpy.context.view_layer.objects.active = obj
    for o in bpy.data.objects:
        o.select_set(o is obj)
    for i in slots:
        obj.material_slots[i].material = mats[0]
    for m in mats:
        t = target(m)
        t.image = img
        for nd in m.node_tree.nodes:
            nd.select = False
        t.select = True
        m.node_tree.nodes.active = t
    bpy.context.scene.cycles.samples = samples
    bpy.ops.object.bake(type=btype, margin=MARGIN, use_clear=True)
    log("baked", what=btype, img=img.name, samples=samples)

# ============================== import
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
sc = bpy.context.scene
sc.render.engine = 'CYCLES'
sc.cycles.device = 'CPU'
sc.render.bake.margin_type = 'EXTEND'
sc.render.bake.use_selected_to_active = False

obj = None
for o in list(bpy.data.objects):
    if o.type == 'MESH' and len(o.data.vertices) > 1000:
        obj = o
    elif o.type == 'MESH':
        log("removing", name=o.name)
        bpy.data.objects.remove(o, do_unlink=True)
OBJ = obj
me = obj.data
orig_mats = [s.material for s in obj.material_slots]
log("mesh", name=obj.name, verts=len(me.vertices), polys=len(me.polygons),
    slots=[m.name if m else None for m in orig_mats])

ca = me.color_attributes[0]
buf = np.zeros(len(ca.data) * 4, dtype=np.float32)
ca.data.foreach_get("color", buf)
cols = np.round(buf.reshape(-1, 4)[:, :3], 3)
uniq, counts = np.unique(cols, axis=0, return_counts=True)
legend = sorted([{"rgb": [round(float(v), 3) for v in uniq[i]], "corners": int(counts[i])} for i in range(len(uniq))],
                key=lambda x: -x["corners"])
log("legend", n=len(legend), colors=legend)

bpy.context.view_layer.objects.active = obj
obj.select_set(True)
try:
    bpy.ops.mesh.customdata_custom_splitnormals_clear(); log("ok", step="clear_custom_normals")
except Exception as e:
    log("warn", step="clear_custom_normals", err=str(e)[:120])
try:
    bpy.ops.object.shade_auto_smooth(angle=math.radians(60)); log("ok", step="auto_smooth")
except Exception as e:
    bpy.ops.object.shade_smooth(); log("warn", step="auto_smooth", err=str(e)[:120])

for layer in list(me.uv_layers):
    me.uv_layers.remove(layer)
me.uv_layers.new(name="UVMap")
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
uvok = False
try:
    bpy.ops.uv.smart_project(angle_limit=math.radians(66.0), island_margin=0.002,
                             area_weight=0.0, correct_aspect=True, scale_to_bounds=False)
    uvok = True; log("ok", step="smart_project")
except Exception as e:
    log("err", step="smart_project", err=str(e)[:200])
if uvok:
    try:
        bpy.ops.uv.pack_islands(rotate=True, margin=0.002)
        log("ok", step="pack_islands")
    except Exception as e:
        log("warn", step="pack_islands", err=str(e)[:200])
bpy.ops.object.mode_set(mode='OBJECT')
if not uvok:
    log("fatal", msg="unwrap failed"); sys.exit(1)

def uv_stats(res=1024):
    layer = me.uv_layers.active
    uv = np.zeros((len(me.loops), 2), dtype=np.float64)
    layer.data.foreach_get("uv", uv.ravel())
    ls = np.zeros(len(me.polygons), dtype=np.int32); me.polygons.foreach_get("loop_start", ls)
    lt = np.zeros(len(me.polygons), dtype=np.int32); me.polygons.foreach_get("loop_total", lt)
    tris = []
    for i in range(len(me.polygons)):
        s, k = ls[i], lt[i]
        pts = uv[s:s + k]
        for j in range(1, k - 1):
            tris.append((pts[0], pts[j], pts[j + 1]))
    tris = np.array(tris)
    e1 = tris[:, 1] - tris[:, 0]; e2 = tris[:, 2] - tris[:, 0]
    area = 0.5 * (e1[:, 0] * e2[:, 1] - e1[:, 1] * e2[:, 0])
    grid = np.zeros((res, res), dtype=np.int32)
    px = tris * res
    for t in range(len(px)):
        p = px[t]
        x0 = max(int(p[:, 0].min()), 0); x1 = min(int(p[:, 0].max()) + 1, res)
        y0 = max(int(p[:, 1].min()), 0); y1 = min(int(p[:, 1].max()) + 1, res)
        if x1 <= x0 or y1 <= y0: continue
        xs, ys = np.meshgrid(np.arange(x0, x1) + 0.5, np.arange(y0, y1) + 0.5)
        d = (p[1, 1] - p[2, 1]) * (p[0, 0] - p[2, 0]) + (p[2, 0] - p[1, 0]) * (p[0, 1] - p[2, 1])
        if abs(d) < 1e-12: continue
        w0 = ((p[1, 1] - p[2, 1]) * (xs - p[2, 0]) + (p[2, 0] - p[1, 0]) * (ys - p[2, 1])) / d
        w1 = ((p[2, 1] - p[0, 1]) * (xs - p[2, 0]) + (p[0, 0] - p[2, 0]) * (ys - p[2, 1])) / d
        w2 = 1.0 - w0 - w1
        grid[y0:y1, x0:x1] += ((w0 >= -1e-6) & (w1 >= -1e-6) & (w2 >= -1e-6)).astype(np.int32)
    used = int((grid > 0).sum()); over = int((grid > 1).sum())
    return dict(area=round(float(area.sum()), 4), coverage=round(used / (res * res), 4),
                overlap_ratio=round(over / max(used, 1), 4))

st = uv_stats()
log("new_uv", **st)
if st["overlap_ratio"] > 0.06:
    log("fatal", msg="overlap too high", **st); sys.exit(1)

slots = list(range(len(obj.material_slots)))
img_alb = new_img("alb", 'sRGB')
img_cov = new_img("cov", 'Non-Color')
img_cur = new_img("cur", 'Non-Color')
img_ao  = new_img("ao",  'Non-Color')
img_nrm = new_img("nrm", 'Non-Color')

# albedo
mats = new_pair()
for m in mats:
    a = m.node_tree.nodes.new("ShaderNodeAttribute"); a.attribute_name = "Color"
    use_emit(m, a.outputs["Color"])
do_bake(img_alb, mats, slots, 'EMIT', 1)
save_img(img_alb, "nezha_albedo.png", 'sRGB')

# coverage
mats = new_pair()
for m in mats:
    use_const(m, (1, 1, 1, 1))
do_bake(img_cov, mats, slots, 'EMIT', 1)
save_img(img_cov, "nezha_coverage.png", 'Non-Color')

# curvature
mats = new_pair()
for m in mats:
    g = m.node_tree.nodes.new("ShaderNodeNewGeometry")
    ramp = m.node_tree.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.40
    ramp.color_ramp.elements[1].position = 0.60
    m.node_tree.links.new(g.outputs["Pointiness"], ramp.inputs[0])
    use_emit(m, ramp.outputs["Color"])
do_bake(img_cur, mats, slots, 'EMIT', 4)
save_img(img_cur, "nezha_curvature.png", 'Non-Color')

# AO
mats = new_pair()
try:
    sc.world.light_settings.distance = 0.05
    log("ok", step="ao_distance", value=sc.world.light_settings.distance)
except Exception as e:
    log("warn", step="ao_distance", err=str(e)[:120])
do_bake(img_ao, mats, slots, 'AO', 64)
save_img(img_ao, "nezha_ao.png", 'Non-Color')

# ============================== high poly -> normal
bpy.ops.object.select_all(action='DESELECT')
obj.select_set(True)
bpy.context.view_layer.objects.active = obj
bpy.ops.object.duplicate()
hi = bpy.context.view_layer.objects.active
hi.name = "nezha_high"
for md in list(hi.modifiers):
    hi.modifiers.remove(md)
hi.parent = None

vg = hi.vertex_groups.new(name="sash")
sash_idx = [i for i, s in enumerate(orig_mats) if s and "HuntianLing" in s.name]
sash_verts = set()
for p in hi.data.polygons:
    if p.material_index in sash_idx:
        sash_verts.update(p.vertices)
vg.add(list(sash_verts), 1.0, 'REPLACE')
log("sash", verts=len(sash_verts), slots=sash_idx)

sub = hi.modifiers.new("sub", 'SUBSURF')
sub.subdivision_type = 'SIMPLE'
sub.levels = 2
sub.render_levels = 2

t1 = bpy.data.textures.new("nz_fine", 'CLOUDS')
t1.noise_scale = 0.045
t1.noise_depth = 3
d1 = hi.modifiers.new("disp1", 'DISPLACE')
d1.texture = t1; d1.texture_coords = 'LOCAL'
d1.strength = 0.0018; d1.mid_level = 0.5

t2 = bpy.data.textures.new("nz_sash", 'CLOUDS')
t2.noise_scale = 0.15
t2.noise_depth = 2
d2 = hi.modifiers.new("disp2", 'DISPLACE')
d2.texture = t2; d2.texture_coords = 'LOCAL'
d2.strength = 0.006; d2.mid_level = 0.5
d2.vertex_group = "sash"

dg = bpy.context.evaluated_depsgraph_get()
ev = hi.evaluated_get(dg)
log("high", polys=len(ev.data.polygons))

nb = bake_mat("BKN")
for i in slots:
    obj.material_slots[i].material = nb
t = target(nb)
t.image = img_nrm
for nd in nb.node_tree.nodes:
    nd.select = False
t.select = True
nb.node_tree.nodes.active = t

bpy.ops.object.select_all(action='DESELECT')
hi.select_set(True)
obj.select_set(True)
bpy.context.view_layer.objects.active = obj
sc.cycles.samples = 32
sc.render.bake.use_selected_to_active = True
sc.render.bake.cage_extrusion = 0.006
sc.render.bake.max_ray_distance = 0.02
sc.render.bake.normal_space = 'TANGENT'
bpy.ops.object.bake(type='NORMAL', margin=MARGIN, use_clear=True)
save_img(img_nrm, "nezha_normal.png", 'Non-Color')
sc.render.bake.use_selected_to_active = False

bpy.data.objects.remove(hi, do_unlink=True)
for i, m in enumerate(orig_mats):
    obj.material_slots[i].material = m
log("ok", step="restore_mats")

# ============================== export
rig = [o for o in bpy.data.objects if o.type == 'ARMATURE']
bpy.ops.object.select_all(action='DESELECT')
obj.select_set(True)
for r in rig:
    r.select_set(True)
bpy.context.view_layer.objects.active = obj
kw = dict(filepath=EXPORT, export_format='GLB', use_selection=True, export_apply=False,
          export_animations=False, export_texcoords=True, export_normals=True)
for extra in (dict(export_tangents=True, export_skins=True, export_yup=True), dict(export_skins=True, export_yup=True), {}):
    k = dict(kw); k.update(extra)
    try:
        bpy.ops.export_scene.gltf(**k)
        log("ok", step="export", extra=list(extra), size=os.path.getsize(EXPORT))
        break
    except TypeError as e:
        log("warn", step="export", extra=list(extra), err=str(e)[:160])
log("done")
