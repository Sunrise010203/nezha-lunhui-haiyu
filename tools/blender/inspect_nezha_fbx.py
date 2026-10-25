"""Inspect supplied motion rigs in a disposable background Blender process."""
import json
import sys
from pathlib import Path

import bpy

ROOT = Path("E:/godot_game_by_fable")
OUT = ROOT / "_review/nezha_arp/animation"
OUT.mkdir(exist_ok=True)
FILES = ["Breathing Idle", "Fight Idle", "Run Forward", "Jumping", "Fall A Loop",
         "Falling To Landing", "Quick Roll To Run", "Bayonet Stab",
         "Stable Sword Outward Slash", "Thrust Slash", "Upward Thrust",
         "Zombie Reaction Hit", "Falling Back Death"]
report = {}
for name in FILES:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    path = Path("C:/Users/Sunrise/Downloads") / (name + ".fbx")
    bpy.ops.import_scene.fbx(filepath=str(path), use_anim=True)
    rigs = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"]
    assert len(rigs) == 1, name
    rig = rigs[0]
    action = rig.animation_data.action
    start, end = action.frame_range
    roots = [b for b in rig.data.bones if not b.parent]
    samples = []
    for frame in (start, (start + end) / 2, end):
        bpy.context.scene.frame_set(int(frame))
        samples.append({b.name: list(rig.matrix_world @ rig.pose.bones[b.name].head) for b in roots})
    report[name] = {
        "objects": [(o.name, o.type) for o in bpy.context.scene.objects],
        "fps": bpy.context.scene.render.fps / bpy.context.scene.render.fps_base,
        "frames": [start, end], "duration": (end - start) / bpy.context.scene.render.fps,
        "scale": list(rig.scale), "rotation": list(rig.rotation_euler),
        "root_samples": samples,
        "bones": [{"name": b.name, "parent": b.parent.name if b.parent else None,
                   "head": list(rig.matrix_world @ b.head_local),
                   "tail": list(rig.matrix_world @ b.tail_local)} for b in rig.data.bones],
    }
    print(name, report[name]["frames"], report[name]["fps"], len(rig.data.bones))
(OUT / "source_inspection.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
addons = {name: getattr(sys.modules.get(name), "__file__", None)
          for name in bpy.context.preferences.addons.keys()}
print("ADDONS=" + json.dumps(addons))
