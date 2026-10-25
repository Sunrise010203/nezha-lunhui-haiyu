"""Measure retargeted root/limb trajectories before gameplay trimming."""
import json
from pathlib import Path
import bpy

OUT = Path("E:/godot_game_by_fable/_review/nezha_arp/animation")
rig = bpy.data.objects["Nezha_ARP_Rig"]
scene = bpy.context.scene
report = {}
for action in bpy.data.actions:
    if not action.name.startswith("Motion_"):
        continue
    rig.animation_data_create()
    rig.animation_data.action = action
    rig.animation_data.action_slot = action.slots[0]
    print("SLOTS", action.name, [(s.identifier, s.target_id_type) for s in action.slots])
    start, end = map(int, action.frame_range)
    frames = []
    for frame in range(start, end + 1):
        scene.frame_set(frame)
        frames.append({"frame": frame, **{label: list(rig.pose.bones[name].head) for label, name in {
            "hips": "c_root_master.x", "hand_r": "hand.r", "hand_l": "hand.l",
            "foot_l": "foot.l", "foot_r": "foot.r", "head": "head.x"}.items()}})
    report[action.name] = frames
(OUT / "motion_trajectories.json").write_text(json.dumps(report), encoding="utf-8")
rig.animation_data.action = None
print(json.dumps({a: {"hips_start": f[0]["hips"], "hips_end": f[-1]["hips"],
                     "hips_z_minmax": [min(x["hips"][2] for x in f), max(x["hips"][2] for x in f)]}
                  for a, f in report.items()}))
print("GLTF_OPTIONS=" + json.dumps({p.identifier: [i.identifier for i in p.enum_items] if p.type == "ENUM" else p.type
      for p in bpy.ops.export_scene.gltf.get_rna_type().properties
      if any(s in p.identifier for s in ("animation", "nla", "action", "sampling"))}))
