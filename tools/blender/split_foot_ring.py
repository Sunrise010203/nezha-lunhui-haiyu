"""从 nezha_opt.glb 里把"脚下乾坤圈/风火轮"拆成独立网格（不蒙皮），
让游戏侧可以单独给它自转、下移（角色悬在圈上，而不是脚插进圈里）。

要点（上一版踩过的坑）：
- glTF 导入后所有顶点默认处于选中状态，直接进 EDIT 会把我的面选择冲掉，
  结果 separate 把整块 mesh 都切走、主体变成空节点、还丢了蒙皮。
  → 必须在 EDIT 模式里用 bmesh 直接改 face.select。
- separate 会把 Armature 修改器一起复制给新对象，必须从新对象上删掉，
  否则它仍被蒙皮、跟着骨骼变形，没法单独下移。
- 这个模型的金色材质（QiankunGold）全部面 = 左右两只风火轮的轮圈+辐条
  （1112 面 = 554 + 558 两个连通块），所以"金色面全取"就是两只轮子。

用法：
  blender --background --factory-startup --python split_foot_ring.py -- <in.glb> <out.glb> [offset]
"""
import sys
import bpy
import bmesh
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
SRC = ARGS[0] if len(ARGS) > 0 else "E:/godot_game_by_fable/001/art/models/nezha_opt.glb"
DST = ARGS[1] if len(ARGS) > 1 else SRC
OFFSET = float(ARGS[2]) if len(ARGS) > 2 else 0.10


def log(*a):
    print("[ring]", *a, flush=True)


def clear_scene():
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)


def main():
    clear_scene()
    bpy.ops.import_scene.gltf(filepath=SRC)

    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    if not meshes:
        log("ERROR no mesh")
        return
    body = max(meshes, key=lambda o: len(o.data.vertices))
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    me = body.data
    log("body", body.name, "verts", len(me.vertices), "polys", len(me.polygons))

    dims = body.dimensions
    up = max(range(3), key=lambda i: dims[i])
    log("dims", tuple(round(d, 3) for d in dims), "up_axis", "XYZ"[up])

    gold_idx = [i for i, m in enumerate(me.materials) if m and "gold" in m.name.lower()]
    log("gold materials", gold_idx, [me.materials[i].name for i in gold_idx])
    gold_faces = [p.index for p in me.polygons if p.material_index in gold_idx]
    log("gold faces", len(gold_faces))
    if not gold_faces:
        log("ERROR no gold faces")
        return

    # 风火轮是"金色辐条/轮毂 + 顶点色绘制的深色外圈"两部分拼的，
    # 只按材质选金色面会把外圈留在主体上 —— 结果脚踝处挂着一个银色细环、
    # 金色轮子却沉到了脚底，看着还是和脚长在一起。
    # 所以：先取金色面的包围盒（外扩 25%），凡是面中心落进这个盒子的面一起选走。
    import mathutils
    gmin = mathutils.Vector((1e9, 1e9, 1e9))
    gmax = mathutils.Vector((-1e9, -1e9, -1e9))
    for p in me.polygons:
        if p.material_index not in gold_idx:
            continue
        for vi in p.vertices:
            co = me.vertices[vi].co
            for k in range(3):
                gmin[k] = min(gmin[k], co[k])
                gmax[k] = max(gmax[k], co[k])
    size = gmax - gmin
    lo = gmin - size * 0.25
    hi = gmax + size * 0.25
    log("gold bbox", tuple(round(v, 3) for v in gmin), tuple(round(v, 3) for v in gmax))

    def in_box(c):
        return lo.x <= c.x <= hi.x and lo.y <= c.y <= hi.y and lo.z <= c.z <= hi.z

    # 找出网格里的连通岛（loose parts）：风火轮的"金色辐条"和"深色外圈"
    # 如果是同一个岛，取整岛就能把外圈一起带走；如果外圈是独立岛，
    # 就用"岛包围盒完整落在扩大后的金色盒子里"来兜底。
    bm0 = bmesh.new()
    bm0.from_mesh(me)
    bm0.faces.ensure_lookup_table()
    seen = set()
    islands = []   # [(set(face_idx), has_gold, bbox_min, bbox_max, size)]
    for f in bm0.faces:
        if f.index in seen:
            continue
        stack = [f]
        comp = set()
        seen.add(f.index)
        while stack:
            cur = stack.pop()
            comp.add(cur.index)
            for e in cur.edges:
                for nf in e.link_faces:
                    if nf.index not in seen:
                        seen.add(nf.index)
                        stack.append(nf)
        gold_in = any(bm0.faces[i].material_index in gold_idx for i in comp)
        mn = mathutils.Vector((1e9, 1e9, 1e9))
        mx = mathutils.Vector((-1e9, -1e9, -1e9))
        for i in comp:
            for v in bm0.faces[i].verts:
                for k in range(3):
                    mn[k] = min(mn[k], v.co[k])
                    mx[k] = max(mx[k], v.co[k])
        islands.append((comp, gold_in, mn, mx))
    bm0.free()
    log("islands", len(islands))
    for comp, gold_in, mn, mx in islands:
        sz = mx - mn
        if gold_in or (mn.x >= lo.x and mx.x <= hi.x and mn.y >= lo.y
                       and mx.y <= hi.y and mn.z >= lo.z and mx.z <= hi.z):
            log("  island faces", len(comp), "gold", gold_in,
                "size", tuple(round(v, 3) for v in sz),
                "min", tuple(round(v, 3) for v in mn))

    want_islands = []
    for comp, gold_in, mn, mx in islands:
        inside = (mn.x >= lo.x and mx.x <= hi.x and mn.y >= lo.y
                  and mx.y <= hi.y and mn.z >= lo.z and mx.z <= hi.z)
        # 只带走"含金色面"或"完整落在金色包围盒内"的岛，避免误伤靴子/身体
        if gold_in or (inside and (mx - mn).x < size.x * 1.6):
            want_islands.append(comp)
    want = set()
    for comp in want_islands:
        want |= comp
    log("want faces", len(want))

    before = {o.name for o in bpy.data.objects}

    # EDIT 模式里用 bmesh 精确选择（glTF 导入后所有顶点默认选中，用 bpy 的
    # poly.select 会被冲掉，必须走 bmesh）
    bpy.ops.object.mode_set(mode="EDIT")
    bm = bmesh.from_edit_mesh(me)
    bm.faces.ensure_lookup_table()
    n_sel = 0
    for f in bm.faces:
        f.select = f.index in want
        if f.select:
            n_sel += 1
    bmesh.update_edit_mesh(me)
    log("selected in edit mode", n_sel)
    bpy.ops.mesh.separate(type="SELECTED")
    bpy.ops.object.mode_set(mode="OBJECT")

    new_objs = [o for o in bpy.data.objects if o.name not in before and o.type == "MESH"]
    if not new_objs:
        log("ERROR separate produced nothing")
        return
    ring = max(new_objs, key=lambda o: len(o.data.vertices))
    ring.name = "nezha_ring"
    log("ring", ring.name, "verts", len(ring.data.vertices), "polys", len(ring.data.polygons))
    log("body after split verts", len(body.data.vertices), "polys", len(body.data.polygons))

    # 圈对象里除了金色风火轮，还混着模型自带的"脚踝银环"（非金色面）。
    # 需求是"删掉银环、只留两只金色风火轮"，所以这里把 ring 里非金色的面全部删掉。
    bpy.ops.object.select_all(action="DESELECT")
    ring.select_set(True)
    bpy.context.view_layer.objects.active = ring
    bpy.ops.object.mode_set(mode="EDIT")
    bmr = bmesh.from_edit_mesh(ring.data)
    bmr.faces.ensure_lookup_table()
    n_del = 0
    for f in bmr.faces:
        f.select = f.material_index not in gold_idx
        if f.select:
            n_del += 1
    bmesh.update_edit_mesh(ring.data)
    bpy.ops.mesh.delete(type="FACE")
    bpy.ops.object.mode_set(mode="OBJECT")
    log("deleted non-gold faces", n_del,
        "-> ring polys", len(ring.data.polygons))

    # 去掉独立对象上的骨架修改器（分离时会一起复制过来）
    removed = []
    for m in list(ring.modifiers):
        removed.append(m.type)
        ring.modifiers.remove(m)
    log("removed modifiers", removed)

    # 判断 up 轴（ring 自身的包围盒）
    rd = ring.dimensions
    log("ring dims", tuple(round(d, 3) for d in rd))

    # 沿 up 轴下移，让轮子沉到脚底以下
    for v in ring.data.vertices:
        v.co[up] -= OFFSET
    ring.data.update()
    log("offset applied", OFFSET)

    # 挂到骨架对象下（跟随角色整体移动，但不参与蒙皮）
    arm = next((o for o in bpy.data.objects if o.type == "ARMATURE"), None)
    if arm:
        ring.parent = arm
        ring.matrix_parent_inverse = arm.matrix_world.inverted()
        log("parented to", arm.name)
    else:
        log("WARN no armature found")

    bpy.ops.export_scene.gltf(
        filepath=DST,
        export_format="GLB",
        use_selection=False,
        export_apply=False,
        export_animations=False,
        export_skins=True,
        export_yup=True,
        export_image_format="JPEG",
        export_image_quality=80,
    )
    log("exported", DST)


main()
