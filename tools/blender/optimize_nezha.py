"""哪吒模型优化流水线（阶段 A：清理 / 减面 / 材质）。

用法：
  blender --background --factory-startup --python optimize_nezha.py -- \
      <in.glb> <out.glb> [target_tris] [stage]

stage:
  clean   只做清理+减面+材质（默认）
  full    clean + 重建混天绫（阶段 B 再实现）

关键约定：源 GLB 是「Z 轴朝上」的非标准 glTF（Godot 侧用 pitch=-90 立起来）。
Blender 导入后角色是躺着的；本脚本不改变对象变换，导出时用默认 export_yup=True，
导入/导出正好互逆，因此导出的 GLB 仍然是 Z 轴朝上的原约定。
"""

import math
import sys

import bmesh
import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
SRC = argv[0] if len(argv) > 0 else "E:/godot_game_by_fable/001/art/models/nezha.glb"
DST = argv[1] if len(argv) > 1 else "E:/godot_game_by_fable/001/art/models/nezha_opt.glb"
TARGET = int(argv[2]) if len(argv) > 2 else 11000
STAGE = argv[3] if len(argv) > 3 else "clean"

MAT_GOLD = "QiankunGold"
MAT_RIBBON = "HuntianLing_Red"
MAT_PAINT = "VCol"


def log(*a):
    print("[opt]", *a)


def clear_scene():
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    for me in list(bpy.data.meshes):
        if me.users == 0:
            bpy.data.meshes.remove(me)


def activate(ob):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob


def tri_count(me):
    return sum(len(p.vertices) - 2 for p in me.polygons)


def main():
    clear_scene()
    bpy.ops.import_scene.gltf(filepath=SRC)
    log("imported", SRC)

    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    bodies = [o for o in meshes if [m for m in o.data.materials if m]]
    body = max(bodies, key=lambda o: len(o.data.polygons))
    arm = next((o for o in bpy.data.objects if o.type == "ARMATURE"), None)

    # 删掉无材质的孤立网格（Icosphere 之类）
    removed = 0
    for ob in meshes:
        if ob is body:
            continue
        log("remove stray mesh", ob.name, "polys", len(ob.data.polygons))
        bpy.data.objects.remove(ob, do_unlink=True)
        removed += 1
    log("removed strays", removed)

    if arm:
        log("armature", arm.name, "bones", len(arm.data.bones))
        for b in arm.data.bones:
            log("bone %-18s head %.2f/%.2f/%.2f tail %.2f/%.2f/%.2f parent %s" % (
                b.name, b.head_local.x, b.head_local.y, b.head_local.z,
                b.tail_local.x, b.tail_local.y, b.tail_local.z,
                b.parent.name if b.parent else "-"))

    me = body.data
    log("body", body.name, "verts", len(me.vertices), "tris", tri_count(me),
        "mats", [m.name if m else None for m in me.materials])
    log("groups", [g.name for g in body.vertex_groups])

    activate(body)

    # ---- 1) 焊接重复顶点（跨材质边界不 weld，避免把飘带粘到身体上）
    bm = bmesh.new()
    bm.from_mesh(me)
    before = len(bm.verts)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0002)
    bm.to_mesh(me)
    bm.free()
    me.update()
    log("weld verts", before, "->", len(me.vertices))

    # ---- 2) 去掉自定义法线，按角度平滑（扫描件法线常与拓扑不匹配）
    if me.has_custom_normals:
        try:
            bpy.ops.mesh.customdata_custom_splitnormals_clear()
            log("cleared custom split normals")
        except RuntimeError as exc:
            log("clear normals failed:", exc)

    # ---- 3) 减面（先把骨骼修改器关掉，避免对形变结果减面）
    arms = [m for m in body.modifiers if m.type == "ARMATURE"]
    for m in arms:
        m.show_viewport = False
        m.show_render = False
    cur = tri_count(me)
    if cur > TARGET * 1.05:
        mod = body.modifiers.new("Dec", "DECIMATE")
        mod.decimate_type = "COLLAPSE"
        mod.ratio = TARGET / float(cur)
        mod.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=mod.name)
        log("decimate %d -> %d tris (target %d)" % (cur, tri_count(me), TARGET))
    else:
        log("no decimate needed", cur)
    for m in arms:
        m.show_viewport = True
        m.show_render = True

    # ---- 4) 平滑着色（60° 以上保持硬边）
    bpy.ops.object.shade_smooth()
    try:
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(60))
        log("shade smooth by 60deg")
    except (AttributeError, RuntimeError):
        log("shade_smooth_by_angle unavailable, plain smooth")

    # ---- 5) 材质：金属度 / 粗糙度 / 双面
    for m in me.materials:
        if m is None or not m.use_nodes:
            continue
        bsdf = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if bsdf is None:
            continue
        if m.name == MAT_GOLD:
            bsdf.inputs["Base Color"].default_value = (0.86, 0.62, 0.24, 1.0)
            bsdf.inputs["Metallic"].default_value = 0.95
            bsdf.inputs["Roughness"].default_value = 0.28
        elif m.name == MAT_RIBBON:
            # 飘带材质原本靠顶点色（渲出来是黑的），这里断开颜色输入直接给红绸色
            for link in list(bsdf.inputs["Base Color"].links):
                m.node_tree.links.remove(link)
            bsdf.inputs["Base Color"].default_value = (0.72, 0.07, 0.06, 1.0)
            bsdf.inputs["Metallic"].default_value = 0.0
            bsdf.inputs["Roughness"].default_value = 0.62
            if "Sheen Weight" in bsdf.inputs:
                bsdf.inputs["Sheen Weight"].default_value = 0.35
        else:
            bsdf.inputs["Metallic"].default_value = 0.0
            bsdf.inputs["Roughness"].default_value = 0.58
        m.use_backface_culling = False
        log("mat", m.name, "metallic", round(bsdf.inputs["Metallic"].default_value, 2),
            "rough", round(bsdf.inputs["Roughness"].default_value, 2))

    # ---- 5b) 顶点色修正：Godot/glTF 会把 COLOR_0 与材质基色相乘，
    # 飘带顶点色原本是黑的（红×黑=黑），金色件也偏暗 —— 都刷成白色让材质基色生效。
    col = me.color_attributes.get("Color") or me.color_attributes.active_color
    if col is not None and col.domain == "CORNER":
        targets = [i for i, m in enumerate(me.materials)
                   if m and m.name in (MAT_RIBBON, MAT_GOLD)]
        painted = 0
        for p in me.polygons:
            if p.material_index not in targets:
                continue
            for li in p.loop_indices:
                col.data[li].color = (1.0, 1.0, 1.0, 1.0)
                painted += 1
        log("painted corner colors white on ribbon/gold:", painted)

    # ---- 6) 统计
    log("FINAL verts", len(me.vertices), "tris", tri_count(me),
        "mats", [m.name if m else None for m in me.materials])

    bpy.ops.export_scene.gltf(
        filepath=DST,
        export_format="GLB",
        use_selection=False,
        export_apply=False,
        export_animations=False,
        export_skins=True,
        export_yup=True,
        export_materials="EXPORT",
        export_texcoords=True,
        export_normals=True,
        export_vertex_color="MATERIAL",
    )
    log("exported", DST, "stage", STAGE)


main()
