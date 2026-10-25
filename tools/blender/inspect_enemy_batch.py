"""Inspect supplied enemy GLBs and render orthographic identification views."""
import hashlib
import json
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector

ROOT = Path("E:/godot_game_by_fable")
OUT = ROOT / "_review/enemies_arp"
OUT.mkdir(parents=True, exist_ok=True)
codes = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [f'{n:03d}' for n in range(1, 9)]
report_path = OUT / 'source_inspection.json'
report = json.loads(report_path.read_text()) if report_path.exists() else {}
for code in codes:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    source = ROOT / "art_source/enemies/source" / (code + ".glb")
    bpy.ops.import_scene.gltf(filepath=str(source))
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    points = np.array([list(o.matrix_world @ v.co) for o in meshes for v in o.data.vertices])
    low, high = points.min(axis=0), points.max(axis=0)
    report[code] = {
        "sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        "bounds": [low.tolist(), high.tolist()],
        "vertices": len(points),
        "triangles": sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in meshes),
        "meshes": [{"name": o.name, "vertices": len(o.data.vertices), "groups": len(o.vertex_groups),
                    "modifiers": [m.type for m in o.modifiers], "materials": [m.name for m in o.data.materials if m]} for o in meshes],
        "armatures": [{"name": o.name, "bones": len(o.data.bones)} for o in bpy.context.scene.objects if o.type == "ARMATURE"],
        "images": [{"name": i.name, "size": list(i.size)} for i in bpy.data.images if i.users],
    }
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.color_type = "TEXTURE"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.show_shadows = True
    scene.display.shading.show_cavity = True
    scene.display.shading.background_type = "WORLD"
    scene.world.color = (0.14, 0.14, 0.14)
    scene.render.resolution_x = 640
    scene.render.resolution_y = 720
    scene.render.resolution_percentage = 100
    camera_data = bpy.data.cameras.new("InspectionCamera")
    camera = bpy.data.objects.new("InspectionCamera", camera_data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    camera_data.type = "ORTHO"
    center = Vector((low + high) / 2)
    size = float(max(high - low))
    camera_data.ortho_scale = size * 1.2
    for label, direction in (("front", (0, -1, 0.04)), ("side", (1, 0, 0.04)), ("back", (0, 1, 0.04))):
        camera.location = center + Vector(direction).normalized() * size * 4
        camera.rotation_euler = (center - camera.location).to_track_quat("-Z", "Y").to_euler()
        camera_data.clip_end = size * 20
        scene.render.filepath = str(OUT / (code + "_" + label + ".png"))
        bpy.ops.render.render(write_still=True)
    np.save(OUT / (code + "_raw_vertices.npy"), points)
    (OUT / "source_inspection.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print("ENEMY_INSPECTED", code, report[code]["bounds"], len(points), report[code]["armatures"], flush=True)
print("ENEMY_INSPECTION_COMPLETE")
