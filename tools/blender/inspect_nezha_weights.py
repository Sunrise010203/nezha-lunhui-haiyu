"""Report initial weight failures and controller properties."""
import json
from pathlib import Path

import bpy
import numpy as np

root = Path("E:/godot_game_by_fable/_review/nezha_arp")
body = bpy.data.objects["Nezha_Body"]
rig = bpy.data.objects["Nezha_ARP_Rig"]
report = {"controls": {}, "unweighted": {}, "groups": {}}
for bone in rig.pose.bones:
    if bone.name.startswith("c_") and any(n in bone.name for n in ("root", "spine", "arm_fk", "forearm_fk", "hand_ik", "thigh_fk", "leg_fk", "foot_ik", "head")):
        report["controls"][bone.name] = {
            "properties": {k: v for k, v in bone.items() if isinstance(v, (int, float, str))},
            "matrix": [list(r) for r in bone.bone.matrix_local],
        }
coords = np.array([list(v.co) for v in body.data.vertices])
missing = [v.index for v in body.data.vertices if not any(g.weight > 1e-5 for g in v.groups)]
report["unweighted"] = {"count": len(missing), "min": coords[missing].min(axis=0).tolist(), "max": coords[missing].max(axis=0).tolist()}
for group in body.vertex_groups:
    points = [v.index for v in body.data.vertices if any(g.group == group.index and g.weight > 0.25 for g in v.groups)]
    if points:
        report["groups"][group.name] = {"count": len(points), "min": coords[points].min(axis=0).tolist(), "max": coords[points].max(axis=0).tolist()}
(root / "weight_inspection.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print(json.dumps(report))
