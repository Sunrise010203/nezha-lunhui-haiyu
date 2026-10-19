"""定位 nezha_body 的每个部件：按材质统计 bbox / 面数，并按顶点色聚类，
找出"黑色飘带"到底是哪个材质、哪些面。
用法：
  blender --background --factory-startup --python diag_nezha.py -- <glb>
"""

import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
GLB = argv[0] if argv else "E:/godot_game_by_fable/001/art/models/nezha.glb"

for ob in list(bpy.data.objects):
    bpy.data.objects.remove(ob, do_unlink=True)
bpy.ops.import_scene.gltf(filepath=GLB)

meshes = [o for o in bpy.data.objects
          if o.type == "MESH" and [m for m in o.data.materials if m]]
body = max(meshes, key=lambda o: len(o.data.polygons))
me = body.data
names = [m.name if m else "(none)" for m in me.materials]
print("[diag] body", body.name, "polys", len(me.polygons), "mats", names)

col_layer = me.color_attributes.active_color
print("[diag] active color attr", col_layer.name if col_layer else None,
      col_layer.domain if col_layer else "", col_layer.data_type if col_layer else "")


def bbox_of(pred):
    mn = Vector((1e9, 1e9, 1e9))
    mx = Vector((-1e9, -1e9, -1e9))
    n = 0
    for p in me.polygons:
        if not pred(p):
            continue
        n += 1
        for vi in p.vertices:
            co = me.vertices[vi].co
            mn = Vector((min(mn.x, co.x), min(mn.y, co.y), min(mn.z, co.z)))
            mx = Vector((max(mx.x, co.x), max(mx.y, co.y), max(mx.z, co.z)))
    if n == 0:
        return n, None, None
    return n, mn, mx


for i, nm in enumerate(names):
    n, mn, mx = bbox_of(lambda p, i=i: p.material_index == i)
    if mn is None:
        print("[diag] mat", i, nm, "faces", n)
        continue
    s = mx - mn
    c = (mn + mx) * 0.5
    print("[diag] mat %d %-18s faces %5d  size %.3f/%.3f/%.3f  center %.2f/%.2f/%.2f"
          % (i, nm, n, s.x, s.y, s.z, c.x, c.y, c.z))

# 顶点色聚类（把每个面的平均色量化到 0.1）
if col_layer:
    buckets = {}
    for p in me.polygons:
        acc = [0.0, 0.0, 0.0]
        for vi in p.vertices:
            c = col_layer.data[vi].color
            acc[0] += c[0]
            acc[1] += c[1]
            acc[2] += c[2]
        k = len(p.vertices)
        q = (round(acc[0] / k * 10), round(acc[1] / k * 10), round(acc[2] / k * 10))
        buckets.setdefault(q, []).append(p.index)
    print("[diag] color buckets:", len(buckets))
    for q, faces in sorted(buckets.items(), key=lambda kv: -len(kv[1]))[:12]:
        mat_i = me.polygons[faces[0]].material_index
        print("[diag]   color %s faces %5d (e.g. %s)" % (
            tuple(round(v / 10.0, 1) for v in q), len(faces), names[mat_i]))

    # 近黑面（混天绫候选）
    def is_dark(p):
        acc = 0.0
        for vi in p.vertices:
            c = col_layer.data[vi].color
            acc += max(c[0], c[1], c[2])
        return acc / len(p.vertices) < 0.25

    n, mn, mx = bbox_of(is_dark)
    if mn is not None:
        s = mx - mn
        print("[diag] DARK faces %d  size %.3f/%.3f/%.3f  bbox %.2f/%.2f/%.2f ~ %.2f/%.2f/%.2f"
              % (n, s.x, s.y, s.z, mn.x, mn.y, mn.z, mx.x, mx.y, mx.z))

print("[diag] done")
