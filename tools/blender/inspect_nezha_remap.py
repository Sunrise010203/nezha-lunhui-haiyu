"""Locate installed ARP remapping API and target control configuration."""
import json
import sys
from pathlib import Path
import bpy

rig = bpy.data.objects["Nezha_ARP_Rig"]
report = {
    "addons": {n: getattr(sys.modules.get(n), "__file__", None) for n in bpy.context.preferences.addons.keys()},
    "operators": [n for n in dir(bpy.ops.arp) if any(s in n for s in ("remap", "retarget", "list", "preset", "scale"))],
    "properties": [p.identifier for p in bpy.context.scene.bl_rna.properties if any(s in p.identifier for s in ("remap", "source", "target", "bones_map"))],
    "controls": {b.name: {"head": list(b.head), "tail": list(b.tail), "parent": b.parent.name if b.parent else None,
                            "constraints": [(c.type, c.name) for c in b.constraints]}
                 for b in rig.pose.bones if b.name.startswith(("c_root", "c_spine", "c_arm_fk", "c_forearm_fk", "c_hand_fk", "c_thigh_fk", "c_leg_fk", "c_foot_fk", "c_toes", "c_neck", "c_head", "c_shoulder"))},
}
Path("E:/godot_game_by_fable/_review/nezha_arp/animation/remap_api.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print(json.dumps({k: v for k, v in report.items() if k != "controls"}))
