"""Import and inspect the supplied Nezha mesh without changing game assets."""
import json
import os
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path("E:/godot_game_by_fable")
SOURCE = ROOT / "art_source/nezha/nezha_model.glb"
OUT = ROOT / "_review/nezha_arp"
OUT.mkdir(parents=True, exist_ok=True)
scene = bpy.data.scenes.new("Nezha_ARP")
bpy.context.window.scene = scene
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
meshes = [o for o in scene.objects if o.type == "MESH"]
report = {"objects": [], "images": [(i.name, list(i.size)) for i in bpy.data.images]}
for obj in meshes:
    vertices = obj.data.vertices
    parents = list(range(len(vertices)))

    def root(i):
        while parents[i] != i:
            parents[i] = parents[parents[i]]
            i = parents[i]
        return i

    for edge in obj.data.edges:
        a, b = edge.vertices
        parents[root(b)] = root(a)
    islands = {}
    for v in vertices:
        islands.setdefault(root(v.index), []).append(v.index)
    components = []
    for indices in sorted(islands.values(), key=len, reverse=True):
        if len(indices) < 15:
            continue
        points = [obj.matrix_world @ vertices[i].co for i in indices]
        lo = [min(p[k] for p in points) for k in range(3)]
        hi = [max(p[k] for p in points) for k in range(3)]
        components.append({"vertices": len(indices), "min": lo, "max": hi})
    report["objects"].append({
        "name": obj.name, "vertices": len(vertices), "faces": len(obj.data.polygons),
        "dimensions": list(obj.dimensions), "matrix": [list(r) for r in obj.matrix_world],
        "materials": [m.name if m else None for m in obj.data.materials],
        "uv_layers": list(obj.data.uv_layers.keys()), "components": components,
    })

points = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
lo = Vector(tuple(min(p[k] for p in points) for k in range(3)))
hi = Vector(tuple(max(p[k] for p in points) for k in range(3)))
center = (lo + hi) / 2
height = max(hi - lo)
report["bounds"] = {"min": list(lo), "max": list(hi)}
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "STUDIO"
scene.display.shading.studiolight_rotate_z = 0.3
scene.display.shading.color_type = "TEXTURE"
scene.display.shading.show_shadows = True
scene.display.shading.show_cavity = True
scene.display.shading.cavity_type = "BOTH"
scene.display.shading.background_type = "WORLD"
scene.world = bpy.data.worlds.new("Nezha_inspection_world")
scene.world.color = (0.15, 0.15, 0.15)
scene.render.resolution_x = 1000
scene.render.resolution_y = 1000
scene.render.resolution_percentage = 100
camera_data = bpy.data.cameras.new("Inspection_Camera")
camera = bpy.data.objects.new("Inspection_Camera", camera_data)
scene.collection.objects.link(camera)
scene.camera = camera
camera_data.type = "ORTHO"
camera_data.ortho_scale = height * 1.15
for name, direction in (("front", (0, -1, 0)), ("back", (0, 1, 0)), ("side", (1, 0, 0)), ("top", (0, 0, 1))):
    camera.location = center + Vector(direction) * height * 3
    camera.rotation_euler = (center - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = str(OUT / ("source_" + name + ".png"))
    bpy.ops.render.render(write_still=True)
(OUT / "source_inspection.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print("INSPECTION=" + json.dumps({"bounds": report["bounds"], "objects": [
    {k: v for k, v in obj.items() if k != "components"} for obj in report["objects"]
]}))
