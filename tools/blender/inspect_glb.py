"""检查一个 GLB 的结构，并渲染几个正交视角，用于判断建模质量。

用法：
  blender --background --factory-startup --python tools/blender/inspect_glb.py -- model.glb out_prefix [views]

输出：
  - stdout 打印网格/材质/贴图/UV/法线/骨骼/动画统计
  - out_prefix_<view>.png 若干张预览图
"""
import bpy
import bmesh
import os
import sys
import math
from mathutils import Vector

argv = sys.argv
args = argv[argv.index("--") + 1:] if "--" in argv else []
GLB = args[0] if len(args) > 0 else ""
PREFIX = args[1] if len(args) > 1 else "inspect"
VIEWS = args[2].split(",") if len(args) > 2 else ["front", "side", "back", "three_quarter"]

assert GLB and os.path.exists(GLB), "GLB not found: %r" % GLB


def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def load(path):
    bpy.ops.import_scene.gltf(filepath=path)


def stats():
    print("=" * 70)
    print("FILE", GLB, "size_MB %.2f" % (os.path.getsize(GLB) / 1048576.0))
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    total_tris = 0
    total_verts = 0
    for ob in meshes:
        me = ob.data
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.triangulate(bm, faces=bm.faces[:])
        tris = len(bm.faces)
        bm.free()
        total_tris += tris
        total_verts += len(me.vertices)
        print("-" * 60)
        print("OBJ", ob.name, "mesh", me.name,
              "verts", len(me.vertices), "polys", len(me.polygons),
              "tris", tris)
        print("   materials", [m.name if m else None for m in me.materials])
        print("   uv_layers", [u.name for u in me.uv_layers],
              "color_attrs", [c.name for c in me.color_attributes])
        print("   custom_normals", me.has_custom_normals,
              "auto_smooth", getattr(me, "use_auto_smooth", "n/a"))
        print("   modifiers", [(m.type, m.name) for m in ob.modifiers])
        print("   shape_keys", len(me.shape_keys.key_blocks) if me.shape_keys else 0)
        print("   parent", ob.parent.name if ob.parent else None,
              "scale", tuple(round(v, 4) for v in ob.scale),
              "rot_deg", tuple(round(math.degrees(v), 1) for v in ob.rotation_euler))
        bb = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
        mn = Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
        mx = Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
        print("   world_bbox_min", tuple(round(v, 3) for v in mn),
              "max", tuple(round(v, 3) for v in mx))
        # 拓扑质量信号：非流形边 / 松散点 / 三角/四边比例
        bm = bmesh.new()
        bm.from_mesh(me)
        nonmanifold = sum(1 for e in bm.edges if not e.is_manifold)
        loose = sum(1 for v in bm.verts if not v.link_edges)
        quads = sum(1 for f in bm.faces if len(f.verts) == 4)
        tris_f = sum(1 for f in bm.faces if len(f.verts) == 3)
        ngons = sum(1 for f in bm.faces if len(f.verts) > 4)
        bm.free()
        print("   topo: quads", quads, "tris", tris_f, "ngons", ngons,
              "nonmanifold_edges", nonmanifold, "loose_verts", loose)
        per_mat = {}
        for p in me.polygons:
            per_mat[p.material_index] = per_mat.get(p.material_index, 0) + 1
        names = [m.name if m else "(none)" for m in me.materials]
        print("   faces_per_material", {names[i] if i < len(names) else i: v
                                        for i, v in sorted(per_mat.items())})
    print("=" * 70)
    print("TOTAL meshes=%d verts=%d tris=%d" % (len(meshes), total_verts, total_tris))
    print("ARMATURES", [o.name for o in bpy.data.objects if o.type == "ARMATURE"])
    print("ACTIONS", [a.name for a in bpy.data.actions])
    print("IMAGES:")
    for im in bpy.data.images:
        if im.name in ("Render Result", "Viewer Node"):
            continue
        print("   ", im.name, "packed", im.packed_file is not None,
              "size", tuple(im.size), "file", im.filepath)

    # 按材质检查：是否用了贴图，贴图挂在哪些通道
    print("MATERIALS:")
    for m in bpy.data.materials:
        if m.name.startswith("Dots") or m.name == "Material":
            continue
        nodes = [n for n in m.node_tree.nodes] if m.use_nodes else []
        texs = [(n.image.name if getattr(n, "image", None) else "?") for n in nodes
                if n.type == "TEX_IMAGE"]
        bsdf = next((n for n in nodes if n.type == "BSDF_PRINCIPLED"), None)
        print("   ", m.name, "nodes", len(nodes), "textures", texs,
              "metallic", round(bsdf.inputs["Metallic"].default_value, 3) if bsdf else "?",
              "roughness", round(bsdf.inputs["Roughness"].default_value, 3) if bsdf else "?")
    print("=" * 70)


def fit_camera(cam, objects):
    """正交相机，把目标装进画面。"""
    mn = Vector((1e9, 1e9, 1e9))
    mx = Vector((-1e9, -1e9, -1e9))
    for ob in objects:
        for c in ob.bound_box:
            w = ob.matrix_world @ Vector(c)
            mn = Vector((min(mn.x, w.x), min(mn.y, w.y), min(mn.z, w.z)))
            mx = Vector((max(mx.x, w.x), max(mx.y, w.y), max(mx.z, w.z)))
    center = (mn + mx) * 0.5
    size = (mx - mn)
    # 竖版画幅时 ortho_scale 对应纵向高度，横向可见宽度 = ortho_scale * (res_x/res_y)
    sc = bpy.context.scene
    aspect = sc.render.resolution_x / float(sc.render.resolution_y)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = max(size.z, size.x / max(aspect, 1e-3)) * 1.15
    cam.location = center + Vector((0, -6, 0))
    cam.rotation_euler = (math.radians(90), 0, 0)
    return center, size


def render_views(center, size):
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in [
        e.identifier for e in sc.render.bl_rna.properties["engine"].enum_items] else "BLENDER_WORKBENCH"
    sc.render.resolution_x = 640
    sc.render.resolution_y = 800
    sc.render.film_transparent = False
    sc.world = bpy.data.worlds.new("W") if sc.world is None else sc.world
    sc.world.use_nodes = True
    bg = sc.world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs[0].default_value = (0.16, 0.18, 0.22, 1.0)
        bg.inputs[1].default_value = 1.2

    cam_data = bpy.data.cameras.new("Cam")
    cam = bpy.data.objects.new("Cam", cam_data)
    bpy.context.collection.objects.link(cam)
    sc.camera = cam
    center, size = fit_camera(cam, [o for o in bpy.data.objects
                                    if o.type == "MESH" and not o.hide_render])
    radius = max(size.x, size.y, size.z)

    # 三点光（必须在 center 算出来之后），距离和功率随模型尺寸缩放
    scale = max(radius, 0.5)
    for name, loc, energy in [
        ("key", Vector((-1.2, -1.6, 1.2)), 340),
        ("fill", Vector((1.4, -1.2, 0.4)), 130),
        ("rim", Vector((0.2, 1.6, 1.2)), 210),
    ]:
        lp = bpy.data.lights.new(name, "AREA")
        lp.energy = energy * scale * scale
        lp.size = 2.0 * scale
        lo = bpy.data.objects.new(name, lp)
        lo.location = center + loc * scale * 1.6
        bpy.context.collection.objects.link(lo)
        # 指向中心
        d = (center - lo.location).normalized()
        lo.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()

    angles = {
        "front": 0.0,
        "side": 90.0,
        "back": 180.0,
        "three_quarter": 35.0,
        "three_quarter_back": 215.0,
        "left": 270.0,
    }
    for v in VIEWS:
        ang = math.radians(angles.get(v, 0.0))
        cam.location = center + Vector((math.sin(ang) * radius * 3.0,
                                        -math.cos(ang) * radius * 3.0, 0.0))
        cam.rotation_euler = (math.radians(90), 0, ang)
        out = "%s_%s.png" % (PREFIX, v)
        sc.render.filepath = out
        bpy.ops.render.render(write_still=True)
        print("[inspect] saved", out)


def upright():
    """这个 GLB 是 Z 轴朝上的（Godot 侧用 pitch=-90 立起来），
    Blender 导入后角色是躺着的，旋转 +90° 绕 X 才方便看。"""
    """这个 GLB 是 Z 轴朝上的（Godot 侧用 pitch=-90 立起来），
    Blender 导入后角色躺着；实测绕 X 转 -90° 才是头朝上的正立姿势
    （+90° 会上下颠倒，见 _baseline/ori_rx±90.png）。"""
    for ob in bpy.data.objects:
        if ob.parent is None and ob.type in ("MESH", "ARMATURE"):
            # glTF 导入的物体是 QUATERNION 旋转模式，直接改 rotation_euler 无效
            ob.rotation_mode = "XYZ"
            ob.rotation_euler.x -= math.radians(90)
    bpy.context.view_layer.update()
    print("[inspect] rotated roots -90deg X for inspection")


def hide_stray():
    """GLB 里常混入无材质的辅助球体，会把取景撑大，渲染时先隐藏。"""
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    if not meshes:
        return
    body = max(meshes, key=lambda o: len(o.data.polygons))
    for ob in meshes:
        if ob is body:
            continue
        if not [m for m in ob.data.materials if m]:
            ob.hide_render = True
            ob.hide_viewport = True
            print("[inspect] hidden unmaterialed mesh", ob.name,
                  "polys", len(ob.data.polygons))
    mn = Vector((1e9, 1e9, 1e9))
    mx = Vector((-1e9, -1e9, -1e9))
    for c in body.bound_box:
        w = body.matrix_world @ Vector(c)
        mn = Vector((min(mn.x, w.x), min(mn.y, w.y), min(mn.z, w.z)))
        mx = Vector((max(mx.x, w.x), max(mx.y, w.y), max(mx.z, w.z)))
    s = mx - mn
    print("[inspect] body bbox size m  x %.3f  y %.3f  z %.3f" % (s.x, s.y, s.z))


def hierarchy():
    print("HIERARCHY:")

    def walk(ob, depth):
        flags = []
        if ob.hide_render:
            flags.append("hide_render")
        if ob.hide_viewport:
            flags.append("hide_viewport")
        print("   " + "  " * depth + "%s (%s)%s" % (
            ob.name, ob.type, (" [" + ",".join(flags) + "]") if flags else ""))
        for c in ob.children:
            walk(c, depth + 1)

    for ob in bpy.data.objects:
        if ob.parent is None:
            walk(ob, 0)


clear()
load(GLB)
stats()
hierarchy()
upright()
hide_stray()
render_views(None, None)
