"""删掉模型脚踝处的"银环"（模型自带的脚环），只留下金色风火轮。

背景：
- 哪吒源模型在脚踝处有一圈深色金属环（用 VCol 顶点色画出来的，不是金色材质），
  看着像"脚被套在环里"，和金色风火轮是两套不同几何。
- 之前把风火轮按材质拆到 nezha_ring 里，但银环仍留在 nezha_body（或反过来），
  导致游戏里角色脚踝一直挂着银环。

做法：
- 对每个网格对象枚举连通岛；
- 找出"金色岛"（QiankunGold 材质）的中心；
- 把非金色、尺寸偏小（最长边 < 0.35m、最薄边 < 0.14m）、且中心靠近金轮（< 0.25m）的岛删掉；
  这些正是脚踝银环。
- 导出（保持原有 skin / 层级，导出设置与 optimize_nezha.py 一致）。

用法：
  blender --background --factory-startup --python strip_ankle_hoops.py -- <in.glb> <out.glb>
"""
import sys
import bpy
import bmesh
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
SRC = ARGS[0] if len(ARGS) > 0 else "E:/godot_game_by_fable/001/art/models/nezha_opt.glb"
DST = ARGS[1] if len(ARGS) > 1 else SRC


def log(*a):
    print("[hoop]", *a, flush=True)


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


def main():
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    bpy.ops.import_scene.gltf(filepath=SRC)

    total_del = 0
    # 先在整份模型里收集所有"金色岛"的中心（银环和风火轮可能分属两个对象，
    # 所以不能用单个对象自己的金色面来判断"离轮子近不近"）。
    global_gold = []
    mesh_objs = [o for o in bpy.data.objects if o.type == "MESH"]
    all_mats = set()
    for ob in mesh_objs:
        for s in ob.material_slots:
            if s.material:
                all_mats.add(s.material.name)
    log("materials", sorted(all_mats))
    for ob in mesh_objs:
        slots = [s.material.name if s.material else "" for s in ob.material_slots]
        gold_idx = [i for i, n in enumerate(slots) if "gold" in n.lower()]
        if not gold_idx:
            continue
        bmg = bmesh.new()
        bmg.from_mesh(ob.data)
        for comp in islands_of(bmg):
            if any(f.material_index in gold_idx for f in comp):
                c = Vector((0, 0, 0))
                for f in comp:
                    c += f.calc_center_median() + ob.location
                global_gold.append(c / len(comp))
        bmg.free()
    log("global gold island centers", len(global_gold))

    for ob in mesh_objs:
        me = ob.data
        slots = [s.material.name if s.material else "" for s in ob.material_slots]
        gold_idx = [i for i, n in enumerate(slots) if "gold" in n.lower()]
        if not gold_idx:
            log("scan no-gold object", ob.name, "slots", slots)
        bm = bmesh.new()
        bm.from_mesh(me)
        comps = islands_of(bm)

        # 金轮（金色岛）中心，用于判断"离轮子近"
        gold_centers = []
        for comp in comps:
            if any(f.material_index in gold_idx for f in comp):
                c = Vector((0, 0, 0))
                for f in comp:
                    c += f.calc_center_median()
                gold_centers.append(c / len(comp))
        log(ob.name, "islands", len(comps), "gold_islands", len(gold_centers))

        doomed = []
        for idx, comp in enumerate(comps):
            mats = {f.material_index for f in comp}
            if mats & set(gold_idx):
                continue
            mn = Vector((1e9, 1e9, 1e9))
            mx = Vector((-1e9, -1e9, -1e9))
            c = Vector((0, 0, 0))
            for f in comp:
                c += f.calc_center_median()
                for v in f.verts:
                    for k in range(3):
                        mn[k] = min(mn[k], v.co[k])
                        mx[k] = max(mx[k], v.co[k])
            c /= len(comp)
            size = mx - mn
            ref = gold_centers if gold_centers else global_gold
            near = min((c - gc).length for gc in ref) if ref else 1e9
            log("  island", idx, "faces", len(comp), "mats", [slots[m] for m in mats],
                "size", tuple(round(v, 3) for v in size), "near_gold", round(near, 3))
            if max(size) < 0.35 and min(size) < 0.14 and near < 0.25:
                doomed.append(idx)
                log("  -> DELETE island", idx, "faces", len(comp))

        if not doomed:
            bm.free()
            continue
        bm.faces.ensure_lookup_table()
        kill = [f for idx in doomed for f in comps[idx]]
        bmesh.ops.delete(bm, geom=kill, context="FACES")
        bm.to_mesh(me)
        bm.free()
        me.update()
        total_del += len(kill)
        log("deleted faces", len(kill), "-> remaining polys", len(me.polygons))

    log("total deleted", total_del)
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
