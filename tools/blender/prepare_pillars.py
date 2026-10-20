"""Procedurally build broken stone columns for the Dragon-Palace ruin, textured
with free Poly Haven PBR maps, and export game-ready GLBs.

Why procedural: Poly Haven has no column/pillar models (0 search hits), but it has
good CC0 stone PBR maps. So the column geometry is generated here and textured.

Run:
    E:\\blender\\app\\blender.exe --background --factory-startup --python prepare_pillars.py

Outputs (height normalised to 1.0 m, pivot at footprint centre):
    001/art/models/props/pillar_a.glb   鐮存崯鏂煴锛堟煴纭€ + 鏌辫韩 + 鏂滃垏鏂锛?    001/art/models/props/pillar_b.glb   鍊炬枩鐭畫鏌?    001/art/models/props/pillar_c.glb   甯︽煴澶寸殑瀹屾暣鏌?"""
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

# 鏌辩鐢ㄧ爩鐭宠创鍥撅紝鏌辫韩鐢ㄩ鍖栫殑娴呯伆宀╅潰锛堝お鍋忔鐨勫博鐭宠创鍥惧湪钃濋浘鍦烘櫙閲屼細鑴忥級
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
## 鏌卞瓙鍦?6~14m 澶栫湅锛?12 璐村浘瓒冲锛涗綋绉ぇ澶存槸 JPEG 璐ㄩ噺
## 锛圥oly Haven 鍘熷浘 1K 灏?~800KB锛屼笁鏍规煴瀛愬厜璐村浘灏?10MB锛?TEX_SIZE = 512
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
    """鎶婅创鍥剧缉鍒?TEX_SIZE 骞?*钀界洏閲嶆柊缂栫爜**銆?
    鍧戯細glTF 瀵煎嚭鍣ㄥ"娌℃湁琚慨鏀硅繃鐨勬枃浠跺浘鍍?浼氬師鏍峰唴宓岋紝鎵€浠?export_image_quality
    瀵瑰畠浠畬鍏ㄦ棤鏁堬紙4 寮?1K JPEG 灏?3.3MB锛夈€傚繀椤诲厛鎶婂儚绱犳敼鎺夈€佸彟瀛樻垚鏂版枃浠讹紝瀵煎嚭鍣?    鎵嶄細鐢ㄦ柊鏂囦欢锛堜綋绉缉鍒?1/6 宸﹀彸锛夈€?    """
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
    mat.use_fake_user = True       # 闃叉娓呭満鏃惰褰撳鍎垮垹鎺夛紙瑙?build_variant 娉ㄩ噴锛?    mat.use_nodes = True
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
        # 鐩存帴鎺?Base Color锛氫腑闂村姞 Mix 鑺傜偣浼氳 glTF 瀵煎嚭鍣ㄨ瘑鍒笉鍒拌创鍥?        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])

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
    # 鍧戯細cutter 娌℃湁鏉愯川鏃讹紝BOOLEAN apply 浼氱粰鐩爣杩藉姞涓€涓?*绌烘潗璐ㄦЫ**锛坕ndex 0锛夛紝
    # 涔嬪悗鍐嶆妸鏉愯川 append 涓婂幓鍙細鍒?index 1锛屾煴韬殑闈粛鐒舵寚鍚戠┖妲?鈫?    # glTF 瀵煎嚭鎴?鏃犳潗璐?= 绾櫧"锛屽湪娓告垙閲屾暣鏍规煴瀛愭洕鐧姐€傛墍浠ヤ袱杈归兘鍏堟寕鍚屼竴涓潗璐ㄣ€?    if mat is not None:
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
    """缁嗗垎涓€灞傦紝缁?Displace 瓒冲椤剁偣鍋氬嚭椋庡寲鐨勮捣浼忥紙鍚﹀垯浣嶇Щ绛変簬娌＄敤锛夈€?""
    mod = ob.modifiers.new("sub", "SUBSURF")
    mod.subdivision_type = "SIMPLE"
    mod.levels = levels
    mod.render_levels = levels
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.modifier_apply(modifier=mod.name)


def smooth_by_angle(ob, angle=38.0):
    """鍦嗘煴闈㈠钩婊戙€佹柇鍙?鍊掕淇濇寔纭竟銆備綆闈㈡暟鏌辫韩濡傛灉鍏ㄥ钩闈㈢潃鑹诧紝渚у厜涓嬩細鐪嬪嚭妫遍潰銆?""
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
    # 娉ㄦ剰锛氳繖閲屼笉瑕佸啀 clear_scene()銆俶ain() 姣忚疆宸茬粡娓呰繃鍦猴紝鑰屾潗璐ㄦ槸鍦ㄦ竻鍦轰箣鍚?    # 鎵嶅垱寤虹殑锛堟鍒?users==0锛夛紝鍐嶆竻涓€娆′細鎶婂畠浠綋瀛ゅ効鍒犳帀 鈫?    # ReferenceError: StructRNA of type Material has been removed
    parts = []

    if which == "a":          # 鐮存崯鏂煴锛氭煴纭€ + 鏌辫韩 + 鏂滃垏鏂 + 鍩哄骇纰庣煶
        plinth = add_box((2.3, 2.3, 0.30), 0.15, "plinth", math.radians(rng.uniform(-3, 3)))
        step = add_cylinder(0.95, 0.28, 0.44, verts=24)
        step.name = "step"
        shaft = add_cylinder(0.72, 8.0, 4.5, verts=32, taper=0.88, name="shaft")
        refine(shaft)
        roughen(shaft, strength=0.05, scale=0.5)
        # 鏂滃垏鏂锛氱敤涓€涓棆杞繃鐨勫ぇ鏂瑰潡鎶婇《閮ㄥ垏寮€
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 8.6))
        cutter = bpy.context.active_object
        cutter.scale = (4.0, 4.0, 2.0)
        cutter.rotation_euler = (math.radians(rng.uniform(18, 30)), 0,
                                 math.radians(rng.uniform(-12, 12)))
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        boolean_cut(shaft, cutter, mat_shaft)
        parts += [plinth, step, shaft]
        # 鍩哄骇纰庣煶
        for i in range(3):
            bpy.ops.mesh.primitive_ico_sphere_add(
                subdivisions=1, radius=rng.uniform(0.18, 0.3),
                location=(rng.uniform(-1.0, 1.0), rng.uniform(-1.0, 1.0), 0.12))
            rock = bpy.context.active_object
            rock.name = "rubble"
            rock.scale.z = 0.7
            parts.append(rock)

    elif which == "b":        # 鍊炬枩鐭畫鏌?        plinth = add_box((2.0, 2.0, 0.26), 0.13, "plinth")
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

    else:                      # 甯︽煴澶寸殑瀹屾暣鏌?        plinth = add_box((2.4, 2.4, 0.32), 0.16, "plinth")
        step = add_cylinder(1.0, 0.26, 0.45, verts=24)
        shaft = add_cylinder(0.72, 7.4, 4.3, verts=32, taper=0.94, name="shaft")
        refine(shaft)
        roughen(shaft, strength=0.035, scale=0.6)
        neck = add_cylinder(0.86, 0.22, 8.1, verts=28)
        cap = add_box((1.7, 1.7, 0.36), 8.4, "capital")
        cap2 = add_box((1.35, 1.35, 0.22), 8.68, "capital2")
        parts += [plinth, step, shaft, neck, cap, cap2]

    # 鏉愯川鍒嗛厤锛氭煴纭€/鏌卞ご鐢ㄧ爩鐭筹紝鏌辫韩鐢ㄥ博闈?    for ob in parts:
        want = mat_shaft if ob.name.startswith(("shaft", "rubble")) else mat_base
        if want not in [m for m in ob.data.materials if m is not None]:
            ob.data.materials.append(want)

    # 鍦嗘鼎鍊掕璁╂１杈规湁鍙楀厜
    for ob in parts:
        if ob.name.startswith(("plinth", "capital")):
            bevel(ob, width=0.03, segments=2)

    # 鏇查潰骞虫粦锛堟柇鍙ｅ拰鍊掕鐨勭‖杈圭敱瑙掑害闃堝€间繚鐣欙級锛岀洅瀛愪繚鎸佸钩闈㈢潃鑹?    for ob in parts:
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

    # UV锛氭櫤鑳藉睍寮€锛岃创鍥炬墠璐村緱涓?    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")

    # 褰掍竴鍖栵細楂樺害 1.0銆佽剼搴曞湪 z=0銆佹按骞冲眳涓?    bb = [obj.matrix_world @ mathutils.Vector(c) for c in obj.bound_box]
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
        # 鑰佺増鏈?Blender 娌℃湁杩欎袱涓叧閿瓧
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
