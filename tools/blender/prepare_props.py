"""Download Poly Haven models, clean them up, and export game-ready GLBs.

Run headless:
    E:\\blender\\app\\blender.exe --background --factory-startup --python prepare_props.py -- --only lantern,rock_a

Why not use the addon's downloader: it imports into the live scene and leaves the
job of decimating / re-exporting to the caller. Here everything is done in one
headless pass, reproducibly, and textures are embedded in the GLB.
"""
import json
import math
import os
import shutil
import sys
import traceback
import urllib.request

import bpy
import mathutils

API = "https://api.polyhaven.com"
UA = "blender-prop-pipeline"
OUT_DIR = r"E:\godot_game_by_fable\001\art\models\props"
TMP_ROOT = r"E:\godot_game_by_fable\tools\blender\_tmp_models"
RES = "1k"

# id -> output name (glTF import is already in metres, no mm conversion needed)
PROPS = {
    "Lantern_01": "lantern",
    "antique_ceramic_vase_01": "urn_porcelain",
    "brass_vase_03": "urn_bronze",
    "rock_09": "rock_a",
    "moon_rock_01": "rock_b",
    "boulder_01": "rock_c",
    "nettle_plant": "kelp_a",
    "dry_branches_medium_01": "dead_branch",
    "caged_hanging_light": "cage",
    "Barrel_01": "barrel",
    "wooden_crate_01": "crate",
    "gothic_statue": "statue",
    "lantern_chandelier_01": "chandelier",
}

MAX_TRIS = {
    "lantern": 40000,
    "urn_porcelain": 16000,
    "urn_bronze": 12000,
    "rock_a": 20000,
    "rock_b": 18000,
    "rock_c": 24000,
    "kelp_a": 24000,
    "dead_branch": 18000,
    "cage": 16000,
    "barrel": 8000,
    "crate": 9000,
    "statue": 24000,
    "chandelier": 14000,
}


def log(*a):
    print("[prep]", *a, flush=True)


def http_json(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.loads(r.read().decode("utf-8"))


def http_download(url, dest):
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=600) as r, open(dest, "wb") as f:
        shutil.copyfileobj(r, f)


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.images,
                  bpy.data.node_groups):
        for item in list(block):
            if item.users == 0:
                try:
                    block.remove(item)
                except Exception:
                    pass


def fetch_model(asset_id):
    files = http_json(f"{API}/files/{asset_id}")
    fmt = "gltf"
    if fmt not in files:
        raise RuntimeError(f"no gltf for {asset_id}")
    res_map = files[fmt]
    res = RES if RES in res_map else sorted(res_map.keys())[0]
    info = res_map[res][fmt]
    workdir = os.path.join(TMP_ROOT, asset_id)
    os.makedirs(workdir, exist_ok=True)

    main_name = info["url"].split("/")[-1]
    main_path = os.path.join(workdir, main_name)
    if not os.path.exists(main_path) or os.path.getsize(main_path) < 1024:
        http_download(info["url"], main_path)
    for rel, inc in (info.get("include") or {}).items():
        dest = os.path.join(workdir, rel)
        if not os.path.exists(dest) or os.path.getsize(dest) < 1024:
            http_download(inc["url"], dest)
    return main_path


def world_bbox(obj):
    bb = [obj.matrix_world @ mathutils.Vector(c) for c in obj.bound_box]
    mn = mathutils.Vector((min(v.x for v in bb), min(v.y for v in bb),
                           min(v.z for v in bb)))
    mx = mathutils.Vector((max(v.x for v in bb), max(v.y for v in bb),
                           max(v.z for v in bb)))
    return mn, mx


def triangle_count(obj):
    obj.data.calc_loop_triangles()
    return len(obj.data.loop_triangles)


def process(asset_id, out_name):
    log("=== ", asset_id, "->", out_name)
    main_path = fetch_model(asset_id)
    clear_scene()
    before = {o.name for o in bpy.data.objects}
    bpy.ops.import_scene.gltf(filepath=main_path)
    imported = [o for o in bpy.data.objects if o.name not in before]
    meshes = [o for o in imported if o.type == "MESH"]
    if not meshes:
        raise RuntimeError("no meshes imported")

    # join everything into one object so the prop is a single node in Godot
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = out_name

    # bake node/parent transforms into the mesh
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)

    tris0 = triangle_count(obj)
    target = MAX_TRIS.get(out_name, 30000)
    if tris0 > target:
        mod = obj.modifiers.new("dec", "DECIMATE")
        mod.decimate_type = "COLLAPSE"
        mod.ratio = max(0.02, target / float(tris0))
        mod.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=mod.name)
        log("  decimated", tris0, "->", triangle_count(obj))
    tris = triangle_count(obj)

    # 1) uniform scale so height (Blender Z, the up axis) becomes exactly 1.0 m.
    #    Godot then scales by the requested height without distorting proportions.
    mn, mx = world_bbox(obj)
    h = mx.z - mn.z
    if h > 1e-6:
        s = 1.0 / h
        obj.scale = (s, s, s)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    # 2) pivot at the footprint centre, bottom resting on z=0
    mn, mx = world_bbox(obj)
    obj.location.x -= (mn.x + mx.x) * 0.5
    obj.location.y -= (mn.y + mx.y) * 0.5
    obj.location.z -= mn.z
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)

    size = mx - mn
    os.makedirs(OUT_DIR, exist_ok=True)
    out_path = os.path.join(OUT_DIR, out_name + ".glb")
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(
        filepath=out_path,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_materials="EXPORT",
        export_yup=True,
    )
    log("  exported", out_path, os.path.getsize(out_path), "bytes",
        "tris", tris, "size_m", [round(v, 3) for v in size])
    return {
        "id": asset_id, "out": out_name, "tris_before": tris0, "tris": tris,
        "size_m": [round(v, 3) for v in size], "bytes": os.path.getsize(out_path),
    }


def main():
    argv = sys.argv
    only = None
    if "--" in argv:
        extra = argv[argv.index("--") + 1:]
        for i, a in enumerate(extra):
            if a == "--only" and i + 1 < len(extra):
                only = set(extra[i + 1].split(","))
    report = []
    for asset_id, out_name in PROPS.items():
        if only and out_name not in only:
            continue
        try:
            report.append(process(asset_id, out_name))
        except Exception as e:
            log("FAILED", asset_id, repr(e))
            traceback.print_exc()
            report.append({"id": asset_id, "out": out_name, "error": repr(e)})
    print("PREP_REPORT:" + json.dumps(report, ensure_ascii=False))


if __name__ == "__main__":
    main()
