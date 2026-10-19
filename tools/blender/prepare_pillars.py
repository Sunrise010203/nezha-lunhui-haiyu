"""Procedurally build broken stone columns for the Dragon-Palace ruin, textured
with free Poly Haven PBR maps, and export game-ready GLBs.

Why procedural: Poly Haven has no column/pillar models (0 search hits), but it has
good CC0 stone PBR maps. So the column geometry is generated here and textured.

Run:
    E:\\blender.exe --background --factory-startup --python prepare_pillars.py

Outputs (height normalised to 1.0 m, pivot at footprint centre):
    001/art/models/props/pillar_a.glb   破损断柱（柱础 + 柱身 + 斜切断裂）
    001/art/models/props/pillar_b.glb   倾斜短残柱
    001/art/models/props/pillar_c.glb   带柱头的完整柱
"""
import json
import math
import os
import random
import urllib.request

import bpy
import mathutils

API = "https://api.polyhaven.com"
UA = "blender-pillar-pipeline"
OUT_DIR = r"E:\godot_game_by_fable\001\art\models\props"
TEX_DIR = r"E:\godot_game_by_fable\tools\blender\library\textures"
RES = "1k"

# 柱础用砌石贴图，柱身用风化的浅灰岩面（太偏棕的岩石贴图在蓝雾场景里会脏）
TEX_BASE = "stone_tiles_02"
TEX_SHAFT = "rock_boulder_dry"

TARGET_TRIS = 9000
MAX_HEIGHT_M = 1.0


# --------------------------------------------------------------------- http
def http_json(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.loads(r.read().decode("utf-8"))


def http_download(url, dest):
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=300) as r, open(dest, "wb") as f:
        while True:
            chunk = r.read(262144)
            if not chunk:
                break
            f.write(chunk)


def fetch_maps(asset_id):
    """Return {'diffuse': path, 'normal': path} for a Poly Haven texture."""
    root = os.path.join(TEX_DIR, asset_id)
    os.makedirs(root, exist_ok=True)
    files = http_json(f"{API}/files/{asset_id}")

    def pick(prefixes):
        for key, val in files.items():
            if not any(key.lower().startswith(p) for p in prefixes):
                continue
            res_map = val.get(RES) or next(iter(val.values()))
            fmt_map = res_map.get("jpg") or res_map.get("png") or next(iter(res_map.values()))
            return fmt_map["url"]
        return None

    out = {}
    diffuse = pick(("diffuse", "diff", "albedo", "color"))
    normal = pick(("nor_gl", "nor", "normal"))
    if diffuse:
        p = os.path.join(root, asset_id + "_diff.jpg")
        if not os.path.exists(p):
            http_download(diffuse, p)
        out["diffuse"] = p
    if normal:
        p = os.path.join(root, asset_id + "_nor.jpg")
        if not os.path.exists(p):
            http_download(normal, p)
        out["normal"] = p
    return out


# ------------------------------------------------------------------ material
## 柱子在 6~14m 外看，512 贴图足够；体积大头是 JPEG 质量
## （Poly Haven 原图 1K 就 ~800KB，三根柱子光贴图就 10MB）
TEX_SIZE = 512
JPEG_QUALITY = 80


def _fit_image(img):
    w, h = img.size
    longest = max(w, h)
    if longest <= TEX_SIZE or w == 0 or h == 0:
        return
    k = TEX_SIZE / float(longest)
    img.scale(max(1, int(round(w * k))), max(1, int(round(h * k))))
    print("[pillar] resize", os.path.basename(img.filepath or "?"),
          (w, h), "->", tuple(img.size), flush=True)


def shrink_maps(maps, tag):
    """把贴图缩到 TEX_SIZE 并**落盘重新编码**。

    坑：glTF 导出器对"没有被修改过的文件图像"会原样内嵌，所以 export_image_quality
    对它们完全无效（4 张 1K JPEG 就 3.3MB）。必须先把像素改掉、另存成新文件，导出器
    才会用新文件（体积缩到 1/6 左右）。
    """
    out = {}
    for kind, path in maps.items():
        img = bpy.data.images.load(path, check_existing=False)
        w, h = img.size
        longest = max(w, h)
        if longest > TEX_SIZE and longest > 0:
            k = TEX_SIZE / float(longest)
            img.scale(max(1, int(round(w * k))), max(1, int(round(h * k))))
        dst = os.path.splitext(path)[0] + "_%s_s%d.jpg" % (tag, TEX_SIZE)
        img.filepath_raw = dst
        img.file_format = "JPEG"
        img.save()
        bpy.data.images.remove(img)
        out[kind] = dst
        print("[pillar] encoded", os.path.basename(dst),
              os.path.getsize(dst), "bytes", flush=True)
    return out


def make_material(name, maps, roughness=0.8, tint=(1.0, 1.0, 1.0)):
    mat = bpy.data.materials.new(name)
    mat.use_fake_user = True       # 防止清场时被当孤儿删掉（见 build_variant 注释）
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()

    out = nt.nodes.new("ShaderNodeOutputMaterial")
    out.location = (400, 0)
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.location = (120, 0)
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    bsdf.inputs["Roughness"].default_value = roughness
    if "Metallic" in bsdf.inputs:
        bsdf.inputs["Metallic"].default_value = 0.0
    bsdf.inputs["Base Color"].default_value = (*tint, 1.0)

    if maps.get("diffuse"):
        img = bpy.data.images.load(maps["diffuse"], check_existing=True)
        _fit_image(img)
        img.pack()
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.location = (-380, 120)
        tex.image = img
        # 直接接 Base Color：中间加 Mix 节点会让 glTF 导出器识别不到贴图
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])

    if maps.get("normal"):
        nimg = bpy.data.images.load(maps["normal"], check_existing=True)
        _fit_image(nimg)
        nimg.pack()
        nimg.colorspace_settings.name = "Non-Color"
        ntex = nt.nodes.new("ShaderNodeTexImage")
        ntex.location = (-380, -180)
        ntex.image = nimg
        nmap = nt.nodes.new("ShaderNodeNormalMap")
        nmap.location = (-80, -180)
        nmap.inputs["Strength"].default_value = 1.0
        nt.links.new(ntex.outputs["Color"], nmap.inputs["Color"])
        nt.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


# ---------------------------------------------------------------- geometry
def add_cylinder(radius, depth, z, verts=32, taper=1.0, name="shaft"):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=verts, radius=radius, depth=depth, location=(0, 0, z))
    ob = bpy.context.active_object
    ob.name = name
    if taper != 1.0:
        for v in ob.data.vertices:
            top = v.co.z > 0
            f = taper if top else 1.0
            v.co.x *= f
            v.co.y *= f
    return ob


def add_box(size, z, name="box", rot_z=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, z))
    ob = bpy.context.active_object
    ob.name = name
    ob.scale = size
    ob.rotation_euler[2] = rot_z
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return ob


def boolean_cut(target, cutter, mat=None):
    # 坑：cutter 没有材质时，BOOLEAN apply 会给目标追加一个**空材质槽**（index 0），
    # 之后再把材质 append 上去只会到 index 1，柱身的面仍然指向空槽 →
    # glTF 导出成"无材质 = 纯白"，在游戏里整根柱子曝白。所以两边都先挂同一个材质。
    if mat is not None:
        cutter.data.materials.clear()
        cutter.data.materials.append(mat)
        if not target.data.materials:
            target.data.materials.append(mat)
    mod = target.modifiers.new("cut", "BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.solver = "EXACT"
    mod.object = cutter
    bpy.context.view_layer.objects.active = target
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(cutter, do_unlink=True)


def roughen(ob, strength=0.03, scale=0.55):
    tex = bpy.data.textures.new(ob.name + "_noise", "CLOUDS")
    tex.noise_scale = scale
    tex.noise_depth = 2
    mod = ob.modifiers.new("disp", "DISPLACE")
    mod.texture = tex
    mod.strength = strength
    mod.mid_level = 0.5
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.modifier_apply(modifier=mod.name)


def bevel(ob, width=0.025, segments=2):
    mod = ob.modifiers.new("bev", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    mod.angle_limit = math.radians(35)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.modifier_apply(modifier=mod.name)


def refine(ob, levels=1):
    """细分一层，给 Displace 足够顶点做出风化的起伏（否则位移等于没用）。"""
    mod = ob.modifiers.new("sub", "SUBSURF")
    mod.subdivision_type = "SIMPLE"
    mod.levels = levels
    mod.render_levels = levels
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.modifier_apply(modifier=mod.name)


def smooth_by_angle(ob, angle=38.0):
    """圆柱面平滑、断口/倒角保持硬边。低面数柱身如果全平面着色，侧光下会看出棱面。"""
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    try:
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(angle))
    except Exception:
        bpy.ops.object.shade_smooth()


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.textures):
        for item in list(block):
            if item.users == 0:
                try:
                    block.remove(item)
                except Exception:
                    pass


# ---------------------------------------------------------------- variants
def build_variant(which, mat_base, mat_shaft, rng):
    # 注意：这里不要再 clear_scene()。main() 每轮已经清过场，而材质是在清场之后
    # 才创建的（此刻 users==0），再清一次会把它们当孤儿删掉 →
    # ReferenceError: StructRNA of type Material has been removed
    parts = []

    if which == "a":          # 破损断柱：柱础 + 柱身 + 斜切断裂 + 基座碎石
        plinth = add_box((2.3, 2.3, 0.30), 0.15, "plinth", math.radians(rng.uniform(-3, 3)))
        step = add_cylinder(0.95, 0.28, 0.44, verts=24)
        step.name = "step"
        shaft = add_cylinder(0.72, 8.0, 4.5, verts=32, taper=0.88, name="shaft")
        refine(shaft)
        roughen(shaft, strength=0.05, scale=0.5)
        # 斜切断裂：用一个旋转过的大方块把顶部切开
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 8.6))
        cutter = bpy.context.active_object
        cutter.scale = (4.0, 4.0, 2.0)
        cutter.rotation_euler = (math.radians(rng.uniform(18, 30)), 0,
                                 math.radians(rng.uniform(-12, 12)))
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        boolean_cut(shaft, cutter, mat_shaft)
        parts += [plinth, step, shaft]
        # 基座碎石
        for i in range(3):
            bpy.ops.mesh.primitive_ico_sphere_add(
                subdivisions=1, radius=rng.uniform(0.18, 0.3),
                location=(rng.uniform(-1.0, 1.0), rng.uniform(-1.0, 1.0), 0.12))
            rock = bpy.context.active_object
            rock.name = "rubble"
            rock.scale.z = 0.7
            parts.append(rock)

    elif which == "b":        # 倾斜短残柱
        plinth = add_box((2.0, 2.0, 0.26), 0.13, "plinth")
        shaft = add_cylinder(0.78, 4.2, 2.3, verts=28, taper=0.92, name="shaft")
        refine(shaft)
        roughen(shaft, strength=0.06, scale=0.45)
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 4.6))
        cutter = bpy.context.active_object
        cutter.scale = (3.5, 3.5, 1.6)
        cutter.rotation_euler = (math.radians(rng.uniform(38, 52)), 0,
                                 math.radians(rng.uniform(-18, 18)))
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        boolean_cut(shaft, cutter, mat_shaft)
        shaft.rotation_euler[1] = math.radians(rng.uniform(-7, -3))
        parts += [plinth, shaft]

    else:                      # 带柱头的完整柱
        plinth = add_box((2.4, 2.4, 0.32), 0.16, "plinth")
        step = add_cylinder(1.0, 0.26, 0.45, verts=24)
        shaft = add_cylinder(0.72, 7.4, 4.3, verts=32, taper=0.94, name="shaft")
        refine(shaft)
        roughen(shaft, strength=0.035, scale=0.6)
        neck = add_cylinder(0.86, 0.22, 8.1, verts=28)
        cap = add_box((1.7, 1.7, 0.36), 8.4, "capital")
        cap2 = add_box((1.35, 1.35, 0.22), 8.68, "capital2")
        parts += [plinth, step, shaft, neck, cap, cap2]

    # 材质分配：柱础/柱头用砌石，柱身用岩面
    for ob in parts:
        want = mat_shaft if ob.name.startswith(("shaft", "rubble")) else mat_base
        if want not in [m for m in ob.data.materials if m is not None]:
            ob.data.materials.append(want)

    # 圆润倒角让棱边有受光
    for ob in parts:
        if ob.name.startswith(("plinth", "capital")):
            bevel(ob, width=0.03, segments=2)

    # 曲面平滑（断口和倒角的硬边由角度阈值保留），盒子保持平面着色
    for ob in parts:
        if ob.name.startswith(("shaft", "step", "neck", "rubble")):
            smooth_by_angle(ob)

    return parts


def join_and_finish(parts, out_name):
    bpy.ops.object.select_all(action="DESELECT")
    for ob in parts:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = out_name
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)

    tris0 = (obj.data.calc_loop_triangles(), len(obj.data.loop_triangles))[1]
    if tris0 > TARGET_TRIS:
        mod = obj.modifiers.new("dec", "DECIMATE")
        mod.decimate_type = "COLLAPSE"
        mod.ratio = TARGET_TRIS / float(tris0)
        bpy.ops.object.modifier_apply(modifier=mod.name)

    # UV：智能展开，贴图才贴得上
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")

    # 归一化：高度 1.0、脚底在 z=0、水平居中
    bb = [obj.matrix_world @ mathutils.Vector(c) for c in obj.bound_box]
    mn = mathutils.Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
    mx = mathutils.Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
    h = max(mx.z - mn.z, 1e-6)
    s = MAX_HEIGHT_M / h
    obj.scale = (s, s, s)
    bpy.ops.object.transform_apply(scale=True)
    bb = [obj.matrix_world @ mathutils.Vector(c) for c in obj.bound_box]
    mn = mathutils.Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
    mx = mathutils.Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
    obj.location.x -= (mn.x + mx.x) * 0.5
    obj.location.y -= (mn.y + mx.y) * 0.5
    obj.location.z -= mn.z
    bpy.ops.object.transform_apply(location=True)

    obj.data.calc_loop_triangles()
    os.makedirs(OUT_DIR, exist_ok=True)
    out = os.path.join(OUT_DIR, out_name + ".glb")
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    try:
        bpy.ops.export_scene.gltf(
            filepath=out, export_format="GLB", use_selection=True,
            export_apply=True, export_materials="EXPORT", export_yup=True,
            export_image_format="JPEG", export_image_quality=JPEG_QUALITY)
    except TypeError:
        # 老版本 Blender 没有这两个关键字
        bpy.ops.export_scene.gltf(
            filepath=out, export_format="GLB", use_selection=True,
            export_apply=True, export_materials="EXPORT", export_yup=True)
    size = mx - mn
    print("[pillar]", out_name, "tris", len(obj.data.loop_triangles),
          "size_m", [round(v, 3) for v in size],
          "bytes", os.path.getsize(out), flush=True)
    return {"out": out_name, "tris": len(obj.data.loop_triangles),
            "bytes": os.path.getsize(out)}


def main():
    base_maps = shrink_maps(fetch_maps(TEX_BASE), "base")
    shaft_maps = shrink_maps(fetch_maps(TEX_SHAFT), "shaft")
    print("[pillar] maps base=", base_maps, "shaft=", shaft_maps, flush=True)

    report = []
    for which, name in (("a", "pillar_a"), ("b", "pillar_b"), ("c", "pillar_c")):
        rng = random.Random(hash(which) & 0xFFFF)
        clear_scene()
        mat_base = make_material("M_" + name + "_base", base_maps,
                                 roughness=0.85, tint=(0.92, 0.96, 1.0))
        mat_shaft = make_material("M_" + name + "_shaft", shaft_maps,
                                  roughness=0.8, tint=(0.9, 0.95, 1.0))
        parts = build_variant(which, mat_base, mat_shaft, rng)
        report.append(join_and_finish(parts, name))
    print("PILLAR_REPORT:" + json.dumps(report), flush=True)


if __name__ == "__main__":
    main()
