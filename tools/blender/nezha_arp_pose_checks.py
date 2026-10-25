"""Render repeatable FK joint tests and measure edge stretch."""
import json
import math
from pathlib import Path

import bpy
import numpy as np
from mathutils import Matrix, Quaternion, Vector

ROOT = Path("E:/godot_game_by_fable")
OUT = ROOT / "_review/nezha_arp"
scene = bpy.context.scene
body = bpy.data.objects["Nezha_Body"]
rig = bpy.data.objects["Nezha_ARP_Rig"]
camera = scene.camera
scene.render.engine = "BLENDER_WORKBENCH"
scene.render.resolution_x = 1000
scene.render.resolution_y = 1100
scene.display.shading.color_type = "TEXTURE"
scene.display.shading.show_cavity = False
scene.display.shading.show_shadows = True
camera.data.ortho_scale = 1.88
rig.show_in_front = True
report = {}
coords = np.array([list(v.co) for v in body.data.vertices])
edges = np.array([list(e.vertices) for e in body.data.edges])
rest_lengths = np.linalg.norm(coords[edges[:, 0]] - coords[edges[:, 1]], axis=1)


def reset():
    for b in rig.pose.bones:
        b.matrix_basis = Matrix.Identity(4)
    for side in ("l", "r"):
        rig.pose.bones["c_hand_ik." + side]["ik_fk_switch"] = 1.0
        rig.pose.bones["c_foot_ik." + side]["ik_fk_switch"] = 1.0
    rig.update_tag()
    bpy.context.view_layer.update()


def rotate(name, axis, degrees):
    bone = rig.pose.bones[name]
    local_axis = bone.bone.matrix_local.to_3x3().inverted() @ Vector(axis)
    bone.rotation_mode = "QUATERNION"
    bone.rotation_quaternion = Quaternion(local_axis, math.radians(degrees))
    bpy.context.view_layer.update()


tests = {
    "rest": [],
    "arms_up": [("c_arm_fk.l", (0, 1, 0), -105), ("c_arm_fk.r", (0, 1, 0), 105)],
    "arms_overhead": [("c_arm_fk.l", (0, 1, 0), -145), ("c_arm_fk.r", (0, 1, 0), 145)],
    "elbows_bent": [("c_arm_fk.l", (1, 0, 0), -40), ("c_forearm_fk.l", (1, 0, 0), -90), ("c_arm_fk.r", (1, 0, 0), -40), ("c_forearm_fk.r", (1, 0, 0), -90)],
    "knee_left": [("c_thigh_fk.l", (1, 0, 0), -60), ("c_leg_fk.l", (1, 0, 0), 95)],
    "knee_right": [("c_thigh_fk.r", (1, 0, 0), -60), ("c_leg_fk.r", (1, 0, 0), 95)],
    "torso_twist": [("c_spine_01.x", (0, 0, 1), 20), ("c_spine_02.x", (0, 0, 1), 25)],
    "turn": [("c_root_master.x", (0, 0, 1), 90)],
}
for name, rotations in tests.items():
    reset()
    for values in rotations:
        rotate(*values)
    bpy.context.view_layer.update()
    evaluated = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = evaluated.to_mesh()
    deformed = np.array([list(v.co) for v in mesh.vertices])
    evaluated.to_mesh_clear()
    lengths = np.linalg.norm(deformed[edges[:, 0]] - deformed[edges[:, 1]], axis=1)
    ratios = lengths / np.maximum(rest_lengths, 1e-9)
    significant = rest_lengths > 0.001
    report[name] = {
        "edge_ratio_p99": float(np.percentile(ratios[significant], 99)),
        "edge_ratio_max": float(ratios[significant].max()),
        "edges_over_2x": int(np.sum((ratios > 2) & significant)),
        "finite_vertices": bool(np.isfinite(deformed).all()),
        "max_displacement": float(np.linalg.norm(deformed - coords, axis=1).max()),
        "worst_edges": [
            {"ratio": float(ratios[i]), "indices": edges[i].tolist(), "center": coords[edges[i]].mean(axis=0).tolist()}
            for i in np.argsort(np.where(significant, ratios, 0))[-8:][::-1]
        ],
    }
    views = [("front", Vector((0, -1, 0)))]
    if name in ("rest", "arms_up", "arms_overhead", "knee_left", "knee_right", "torso_twist"):
        views.append(("three_quarter", Vector((0.8, -1, 0.08))))
    if name in ("rest", "knee_left", "knee_right", "torso_twist"):
        views.append(("side", Vector((1, 0, 0))))
    for view, direction in views:
        target = Vector((0, 0, 0.82))
        camera.location = target + direction.normalized() * 5
        camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = str(OUT / (name + "_" + view + ".png"))
        bpy.ops.render.render(write_still=True)
        if name == "rest":
            from bpy_extras.object_utils import world_to_camera_view
            bone_lines = []
            for b in rig.data.bones:
                if "ref" not in b.name or any(p in b.name for p in ("thumb", "pinky", "ring", "middle", "index", "bank", "heel")):
                    continue
                pts = [world_to_camera_view(scene, camera, rig.matrix_world @ p) for p in (b.head_local, b.tail_local)]
                bone_lines.append({"name": b.name, "points": [[p.x * 1000, (1 - p.y) * 1100] for p in pts]})
            (OUT / ("skeleton_" + view + ".json")).write_text(json.dumps(bone_lines), encoding="utf-8")
reset()
(OUT / "pose_metrics.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print("POSE_METRICS=" + json.dumps({n: {k: v for k, v in r.items() if k != "worst_edges"} for n, r in report.items()}))
