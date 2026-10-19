"""修正风火轮拆分：删掉脚踝银环、把真正的金色风火轮拆成独立网格并下移。

背景（实测结论，和最初的判断相反）：
- 模型里 `QiankunGold` 材质的 1112 面其实不是金色风火轮，而是**脚踝那一对银灰色金属环**
  （baseColor 0.8 灰 + metallic 0.95，渲出来是铬色）；把它们藏起来，脚踝环消失、金轮还在。
- 真正的金色风火轮是主体 `VCol` 顶点色画出来的两块独立连通岛（各约 0.36 x 0.10 x 0.36 m，
  扁平、靠近脚底）。

所以本脚本：
1. 删掉主体里所有 `QiankunGold` 材质的岛 → 脚踝银环消失；
2. 把主体里"VCol + 体积够大 + 薄 + 顶点色偏金"的岛（就是两只风火轮）分离成 `nezha_ring`，
   去掉 Armature 修改器（脱离蒙皮）、沿 up 轴下移 OFFSET、挂到 `rig` 下；
3. 导出 GLB（保留 skin，导出参数与 optimize_nezha.py 一致）。

用法：
  blender --background --factory-startup --python fix_fire_wheels.py -- <in.glb> <out.glb> [offset]
"""
import sys
import bpy
import bmesh
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
SRC = ARGS[0] if len(ARGS) > 0 else "E:/godot_game_by_fable/001/art/models/nezha_opt_presplit.glb"
DST = ARGS[1] if len(ARGS) > 1 else SRC
OFFSET = float(ARGS[2]) if len(ARGS) > 2 else 0.30


def log(*a):
    print("[fw]", *a, flush=True)


def islands_of(bm):
    bm.faces.ensure_lookup_table()
    seen = set()
    out = []
    for f in bm.faces:
        if f.index in seen:
            continue
        stack = [f]
        seen.add(f.index)
        comp = []
        while stack:
            cur = stack.pop()
            comp.append(cur)
            for e in cur.edges:
                for nf in e.link_faces:
                    if nf.index not in seen:
                        seen.add(nf.index)
                        stack.append(nf)
        out.append(comp)
    return out


def comp_stats(comp, slots, color_layer):
    mn = Vector((1e9, 1e9, 1e9))
    mx = Vector((-1e9, -1e9, -1e9))
    c = Vector((0, 0, 0))
    col = [0.0, 0.0, 0.0, 0.0]
    ncol = 0
    for f in comp:
        c += f.calc_center_median()
        for v in f.verts:
            for k in range(3):
                mn[k] = min(mn[k], v.co[k])
                mx[k] = max(mx[k], v.co[k])
        if color_layer is not None:
            for loop in f.loops:
                d = color_layer.data[loop.index].color
                col[0] += d[0]
                col[1] += d[1]
                col[2] += d[2]
                col[3] += d[3]
                ncol += 1
    c /= len(comp)
    if ncol:
        col = [x / ncol for x in col]
    mats = sorted({slots[f.material_index] for f in comp})
    return c, mn, mx, mats, col


def main():
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    bpy.ops.import_scene.gltf(filepath=SRC)

    meshes = [o for o in bpy.data.objects if o.type == "MESH" and o.material_slots]
    body = max(meshes, key=lambda o: len(o.data.vertices))
    log("body", body.name, "verts", len(body.data.vertices), "polys", len(body.data.polygons))

    me = body.data
    slots = [s.material.name if s.material else "" for s in body.material_slots]
    log("slots", slots)

    color_layer = None
    for ca in me.color_attributes:
        if ca.domain == "CORNER" and ca.data:
            color_layer = ca
            log("color attribute", ca.name, ca.domain, ca.data_type)
            break

    dims = body.dimensions
    up = max(range(3), key=lambda i: dims[i])
    log("dims", tuple(round(d, 3) for d in dims), "up_axis", "XYZ"[up])

    bm = bmesh.new()
    bm.from_mesh(me)
    comps = islands_of(bm)
    log("body islands", len(comps))

    hoop_idx = {i for i, n in enumerate(slots) if "gold" in n.lower()}
    hoop_comps = []
    wheel_comps = []
    hoop_centers = []
    for idx, comp in enumerate(comps):
        c, mn, mx, mats, col = comp_stats(comp, slots, color_layer)
        size = mx - mn
        log("island", idx, "faces", len(comp), "mats", mats,
            "size", tuple(round(v, 3) for v in size),
            "center", tuple(round(v, 3) for v in c),
            "vcol", [round(v, 2) for v in col])
        if any(slots[f.material_index] in ("QiankunGold",) for f in comp):
            hoop_comps.append(idx)
            hoop_centers.append(c)
            continue
        # 风火轮：扁平大件、顶点色偏金、而且紧贴脚踝环（同一双鞋的位置）
        near_hoop = min((c - hc).length for hc in hoop_centers) if hoop_centers else 1e9
        if max(size) > 0.25 and min(size) < 0.16 and col[0] > 0.5 and col[1] > 0.3:
            if near_hoop < 0.35:
                wheel_comps.append(idx)
                log("  -> WHEEL candidate", idx, "faces", len(comp), "near_hoop", round(near_hoop, 3))
            else:
                log("  -> rejected gold-ish island", idx, "far from hoops", round(near_hoop, 3))

    log("hoop islands", hoop_comps, "wheel islands", wheel_comps)

    # 1) 删银环
    if hoop_comps:
        bm.faces.ensure_lookup_table()
        kill = [f for idx in hoop_comps for f in comps[idx]]
        bmesh.ops.delete(bm, geom=kill, context="FACES")
        log("deleted hoop faces", len(kill))
    bm.to_mesh(me)
    bm.free()
    me.update()

    # 2) 选风火轮面 → separate
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.mode_set(mode="EDIT")
    bem = bmesh.from_edit_mesh(me)
    bem.faces.ensure_lookup_table()
    n_sel = 0
    for f in bem.faces:
        f.select = False
    # 重新按几何位置选：风火轮在"扁平大件"区域，用之前记录的包围盒判断
    wheel_boxes = []
    for idx in wheel_comps:
        pass
    # 直接按"顶点色 + 尺寸"在编辑网格里重算连通岛
    import collections
    bem.faces.ensure_lookup_table()
    seen = set()
    wheel_faces = []
    for f in bem.faces:
        if f.index in seen:
            continue
        stack = [f]
        seen.add(f.index)
        comp = []
        while stack:
            cur = stack.pop()
            comp.append(cur)
            for e in cur.edges:
                for nf in e.link_faces:
                    if nf.index not in seen:
                        seen.add(nf.index)
                        stack.append(nf)
        mn = Vector((1e9, 1e9, 1e9))
        mx = Vector((-1e9, -1e9, -1e9))
        col = [0.0, 0.0, 0.0, 0.0]
        ncol = 0
        for ff in comp:
            for v in ff.verts:
                for k in range(3):
                    mn[k] = min(mn[k], v.co[k])
                    mx[k] = max(mx[k], v.co[k])
            if color_layer is not None:
                for loop in ff.loops:
                    d = color_layer.data[loop.index].color
                    col[0] += d[0]
                    col[1] += d[1]
                    col[2] += d[2]
                    ncol += 1
        if ncol:
            col = [x / ncol for x in col]
        size = mx - mn
        ctr = (mn + mx) * 0.5
        near_hoop = min((ctr - hc).length for hc in hoop_centers) if hoop_centers else 1e9
        if (max(size) > 0.25 and min(size) < 0.16
                and col[0] > 0.5 and col[1] > 0.3 and near_hoop < 0.35):
            wheel_faces.extend(comp)
    log("wheel faces selected", len(wheel_faces))
    for ff in wheel_faces:
        ff.select = True
        n_sel += 1
    bmesh.update_edit_mesh(me)
    if n_sel == 0:
        bpy.ops.object.mode_set(mode="OBJECT")
        log("ERROR no wheel faces selected")
        return
    bpy.ops.mesh.separate(type="SELECTED")
    bpy.ops.object.mode_set(mode="OBJECT")

    new_objs = [o for o in bpy.data.objects
                if o.type == "MESH" and o.name != body.name and "Icosphere" not in o.name]
    if not new_objs:
        log("ERROR separate produced nothing")
        return
    ring = max(new_objs, key=lambda o: len(o.data.vertices))
    ring.name = "nezha_ring"
    log("ring verts", len(ring.data.vertices), "polys", len(ring.data.polygons))
    log("body after split verts", len(body.data.vertices), "polys", len(body.data.polygons))

    for m in list(ring.modifiers):
        log("remove modifier", m.type)
        ring.modifiers.remove(m)

    for v in ring.data.vertices:
        v.co[up] -= OFFSET
    ring.data.update()
    log("offset applied", OFFSET, "along", "XYZ"[up])

    arm = next((o for o in bpy.data.objects if o.type == "ARMATURE"), None)
    if arm:
        ring.parent = arm
        ring.matrix_parent_inverse = arm.matrix_world.inverted()
        log("parented to", arm.name)

    bpy.ops.export_scene.gltf(
        filepath=DST,
        export_format="GLB",
        use_selection=False,
        export_apply=False,
        export_skins=True,
        export_animations=False,
        export_vertex_color="MATERIAL",
        export_image_format="AUTO",
        export_yup=True,
    )
    log("exported", DST)


main()
