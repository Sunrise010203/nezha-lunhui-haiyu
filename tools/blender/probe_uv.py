
import bpy, sys, json, os, math
import numpy as np

SRC = r"E:\godot_game_by_fable\001\art\models\nezha_opt.glb"
RES = 1024

def log(tag, **kw):
    print("@@PROBE " + json.dumps({"tag": tag, **kw}, ensure_ascii=False))

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)

meshes = [o for o in bpy.data.objects if o.type == 'MESH']
log("objects", meshes=[{"name": o.name, "verts": len(o.data.vertices), "polys": len(o.data.polygons),
                        "uv": [l.name for l in o.data.uv_layers]} for o in meshes])

obj = None
for o in meshes:
    if len(o.data.vertices) > 1000:
        obj = o
if obj is None:
    log("error", msg="no mesh")
    sys.exit(1)

me = obj.data
for layer in me.uv_layers:
    uv = np.zeros((len(me.loops), 2), dtype=np.float64)
    layer.data.foreach_get("uv", uv.ravel())
    tri_uv = uv.reshape(-1, 3, 2) if len(uv) % 3 == 0 else None
    # build triangulated loop-triples from polygons (mesh is all tris ideally)
    a = np.zeros(len(me.polygons), dtype=np.int32)
    me.polygons.foreach_get("loop_start", a)
    nloops = np.zeros(len(me.polygons), dtype=np.int32)
    me.polygons.foreach_get("loop_total", nloops)
    tris = []
    for i in range(len(me.polygons)):
        s = a[i]; n = nloops[i]
        pts = uv[s:s+n]
        for k in range(1, n-1):
            tris.append((pts[0], pts[k], pts[k+1]))
    tris = np.array(tris)  # (T,3,2)
    e1 = tris[:, 1] - tris[:, 0]
    e2 = tris[:, 2] - tris[:, 0]
    area = 0.5 * (e1[:, 0]*e2[:, 1] - e1[:, 1]*e2[:, 0])
    # raster coverage / overlap
    grid = np.zeros((RES, RES), dtype=np.int32)
    px = tris * RES
    for t in range(len(px)):
        p = px[t]
        x0 = max(int(np.floor(p[:, 0].min())), 0); x1 = min(int(np.ceil(p[:, 0].max()))+1, RES)
        y0 = max(int(np.floor(p[:, 1].min())), 0); y1 = min(int(np.ceil(p[:, 1].max()))+1, RES)
        if x1 <= x0 or y1 <= y0:
            continue
        xs, ys = np.meshgrid(np.arange(x0, x1)+0.5, np.arange(y0, y1)+0.5)
        d = (p[1, 1]-p[2, 1])*(p[0, 0]-p[2, 0]) + (p[2, 0]-p[1, 0])*(p[0, 1]-p[2, 1])
        if abs(d) < 1e-12:
            continue
        w0 = ((p[1, 1]-p[2, 1])*(xs-p[2, 0]) + (p[2, 0]-p[1, 0])*(ys-p[2, 1])) / d
        w1 = ((p[2, 1]-p[0, 1])*(xs-p[2, 0]) + (p[0, 0]-p[2, 0])*(ys-p[2, 1])) / d
        w2 = 1.0 - w0 - w1
        inside = (w0 >= -1e-6) & (w1 >= -1e-6) & (w2 >= -1e-6)
        grid[y0:y1, x0:x1] += inside.astype(np.int32)
    used = int((grid > 0).sum())
    over = int((grid > 1).sum())
    log("uvlayer", name=layer.name, tris=len(tris),
        area_sum=round(float(area.sum()), 4),
        area_neg=round(float(area[area < 0].sum()), 4),
        uv_min=[round(float(uv[:,0].min()),4), round(float(uv[:,1].min()),4)],
        uv_max=[round(float(uv[:,0].max()),4), round(float(uv[:,1].max()),4)],
        coverage=round(used/(RES*RES), 4),
        overlap=round(over/(RES*RES), 4),
        overlap_used_ratio=round(over/max(used,1), 4))

cols = me.color_attributes
log("colors", attrs=[{"name": c.name, "domain": c.domain, "type": c.data_type} for c in cols])
if len(cols):
    c = cols[0]
    n = len(c.data)
    buf = np.zeros(n*4, dtype=np.float32)
    c.data.foreach_get("color", buf)
    buf = buf.reshape(-1, 4)
    log("colstats", mean=[round(float(v),3) for v in buf[:,:3].mean(0)],
        std=[round(float(v),3) for v in buf[:,:3].std(0)],
        uniq=int(len(np.unique(np.round(buf[:,:3],2), axis=0))))
log("done")
