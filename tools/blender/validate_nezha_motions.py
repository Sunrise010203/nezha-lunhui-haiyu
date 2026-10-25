"""Background-only verification of the exported animation and skinned vertices."""
import json
from pathlib import Path
import bpy
import numpy as np
from mathutils import Matrix
from mathutils.kdtree import KDTree

ROOT = Path("E:/godot_game_by_fable")
OUT = ROOT / "_review/nezha_arp/animation"
clips = json.loads((OUT / "gameplay_clips.json").read_text())
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = 30
bpy.ops.import_scene.gltf(filepath=str(ROOT / "001/art/models/nezha_arp.glb"))
scene = bpy.context.scene
body = next(o for o in scene.objects if o.type == "MESH" and any(m.type == "ARMATURE" for m in o.modifiers))
rig = next(o for o in scene.objects if o.type == "ARMATURE")
assert sum(b.use_deform for b in rig.data.bones) == 67
rest = np.load(ROOT / "_review/nezha_arp/reference_Rest.npy")
tree = KDTree(len(rest))
for index, point in enumerate(rest):
    tree.insert(point, index)
tree.balance()
matches = [tree.find(body.matrix_world @ v.co) for v in body.data.vertices]
assert max(distance for _, _, distance in matches) < 1e-5
mapping = np.array([index for _, index, _ in matches])
report = {}
for label, clip in clips.items():
    action = bpy.data.actions[label]
    rig.animation_data.action = None
    for bone in rig.pose.bones:
        bone.matrix_basis = Matrix.Identity(4)
    rig.animation_data.action = action
    rig.animation_data.action_slot = action.slots[0]
    errors = []
    first = action.frame_range[0]
    for checked in clip["checked_frames"]:
        frame = checked["frame"]
        scene.frame_set(int(first + frame - 1))
        evaluated = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
        mesh = evaluated.to_mesh()
        points = np.array([list(body.matrix_world @ v.co) for v in mesh.vertices])
        evaluated.to_mesh_clear()
        reference = np.load(OUT / ("reference_" + label + "_" + str(frame) + ".npy"))[mapping]
        error = float(np.linalg.norm(points - reference, axis=1).max())
        assert error < 0.00015, (label, frame, error)
        assert np.isfinite(points).all()
        errors.append({"frame": frame, "max_error_m": error})
    report[label] = {"passed": True, "frames": errors}
(OUT / "motion_export_validation.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print("MOTION_ROUNDTRIP_PASS clips=" + str(len(report)) + " max_error_m=" + str(max(f["max_error_m"] for r in report.values() for f in r["frames"])))
