"""Derive small chapter-1 scenery GLBs; leave source assets unchanged.

E:/blender/app/blender.exe --background --factory-startup --python tools/blender/prepare_ch1_ruins.py
"""
import json
from pathlib import Path

import bpy
import bmesh

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "001/art/models/glb_game"
OUT = ROOT / "001/art/models/ch1_ruins"
ASSETS = {
    "lantern": ("T16_lantern.glb", 2400),
    "pillar_base": ("T17_pillar.glb", 1400),
    "pillar_shaft": ("T18_shaft.glb", 1200),
    "railing": ("T19_balustrade.glb", 1600),
    "post": ("T20_post.glb", 900),
    "steps": ("T21_step.glb", 1800),
    "arch": ("T22_arch.glb", 4200),
    "rubble": ("T23_rubble.glb", 850),
    "barnacle": ("T24_barnacle.glb", 500),
    "capital": ("3.glb", 2600),
    "coral": ("2.glb", 1800),
}


def triangles(obj):
    obj.data.calc_loop_triangles()
    return len(obj.data.loop_triangles)


OUT.mkdir(parents=True, exist_ok=True)
report = {}
for name, (source, budget) in ASSETS.items():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(SOURCE / source))
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    before = sum(triangles(o) for o in meshes)
    for obj in meshes:
        # Source GLBs split vertices at UV/normal seams. Weld coincident geometry
        # before decimation, otherwise collapsed islands leave triangular holes.
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=0.0001)
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        bm.to_mesh(obj.data)
        bm.free()
        obj.data.update()
        bpy.context.view_layer.objects.active = obj
        modifier = obj.modifiers.new("Scenery budget", "DECIMATE")
        modifier.ratio = min(1.0, budget / max(before, 1))
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    for img in bpy.data.images:
        if img.size[0] > 512 or img.size[1] > 512:
            factor = 512 / max(img.size)
            img.scale(max(1, round(img.size[0] * factor)), max(1, round(img.size[1] * factor)))
            img.pack()
    after = sum(triangles(o) for o in meshes)
    bpy.ops.export_scene.gltf(
        filepath=str(OUT / (name + ".glb")), export_format="GLB",
        export_animations=False, export_image_format="AUTO",
    )
    report[name] = {"source": source, "before": before, "triangles": after, "budget": budget}
    print("RUINS_ASSET", name, before, "->", after, flush=True)
(OUT / "budgets.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
