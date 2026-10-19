"""只删脚踝银环（QiankunGold 材质的 1112 面），不做任何拆分。

实测结论：`QiankunGold` 材质的 1112 面 = 脚踝那一对银灰金属环（baseColor 0.8 灰、
metallic 0.95）；真正的金色风火轮是主体 `VCol` 顶点色画出来的，本来就在脚上。
所以把银环删掉、角色整体抬升，就得到"踩着风火轮悬浮"的效果，不需要拆网格。

用法：
  blender --background --factory-startup --python strip_hoops_only.py -- <in.glb> <out.glb>
"""
import sys
import bpy
import bmesh

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
SRC = ARGS[0] if len(ARGS) > 0 else "E:/godot_game_by_fable/001/art/models/nezha_opt_presplit.glb"
DST = ARGS[1] if len(ARGS) > 1 else SRC


def log(*a):
    print("[hoop]", *a, flush=True)


def main():
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    bpy.ops.import_scene.gltf(filepath=SRC)

    total = 0
    for ob in [o for o in bpy.data.objects if o.type == "MESH" and o.material_slots]:
        slots = [s.material.name if s.material else "" for s in ob.material_slots]
        gold_idx = [i for i, n in enumerate(slots) if "gold" in n.lower()]
        if not gold_idx:
            log("skip", ob.name, slots)
            continue
        me = ob.data
        bm = bmesh.new()
        bm.from_mesh(me)
        bm.faces.ensure_lookup_table()
        kill = [f for f in bm.faces if f.material_index in gold_idx]
        if not kill:
            bm.free()
            continue
        log("deleting", len(kill), "gold faces from", ob.name)
        bmesh.ops.delete(bm, geom=kill, context="FACES")
        bm.to_mesh(me)
        bm.free()
        me.update()
        total += len(kill)
        log("remaining polys", len(me.polygons))
        # 金色槽删空后可以保留，glTF 导出会忽略空材质

    log("total deleted", total)
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
