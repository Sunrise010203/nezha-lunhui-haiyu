"""Check that each saved QA action reproduces the reviewed pose."""
import json
from pathlib import Path

import bpy
import numpy as np
from mathutils import Matrix

OUT = Path("E:/godot_game_by_fable/_review/nezha_arp")
rig = bpy.data.objects["Nezha_ARP_Rig"]
body = bpy.data.objects["Nezha_Body"]
scene = bpy.context.scene
report = {}
for label in ("RaiseArms", "ArmsOverhead", "Elbows", "LeftKnee", "RightKnee", "TorsoTwist", "Turn"):
    rig.animation_data.action = bpy.data.actions["QA_" + label]
    scene.frame_set(16)
    bpy.context.view_layer.update()
    evaluated = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = evaluated.to_mesh()
    coords = np.array([list(v.co) for v in mesh.vertices])
    evaluated.to_mesh_clear()
    error = float(np.linalg.norm(coords - np.load(OUT / ("reference_" + label + ".npy")), axis=1).max())
    report[label] = error
rig.animation_data.action = None
scene.frame_set(1)
for bone in rig.pose.bones:
    bone.matrix_basis = Matrix.Identity(4)
bpy.context.view_layer.update()
(OUT / "action_validation.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print("ACTION_VALIDATION=" + json.dumps(report))
assert max(report.values()) < 0.0001
