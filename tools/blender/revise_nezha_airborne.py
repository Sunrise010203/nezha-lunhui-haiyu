"""Replace the generic Mixamo airborne poses with the original game's silhouettes."""
import json
from pathlib import Path

import bpy
import numpy as np
from mathutils import Matrix, Quaternion, Vector

ROOT = Path("E:/godot_game_by_fable")
OUT = ROOT / "_review/nezha_arp/animation"
scene = bpy.context.scene
rig = bpy.data.objects["Nezha_ARP_Rig"]
body = bpy.data.objects["Nezha_Body"]
controls = ["c_root_master.x", "c_spine_01.x", "c_spine_02.x", "c_neck.x", "c_head.x"]
for side in ("l", "r"):
    controls.extend("c_" + limb + "." + side for limb in (
        "shoulder", "arm_fk", "forearm_fk", "hand_fk", "thigh_fk", "leg_fk", "foot_fk", "toes_fk"))


def reset():
    rig.animation_data.action = None
    for bone in rig.pose.bones:
        bone.matrix_basis = Matrix.Identity(4)
    for side in ("l", "r"):
        for limb in ("hand", "foot"):
            rig.pose.bones["c_" + limb + "_ik." + side]["ik_fk_switch"] = 1.0
    bpy.context.view_layer.update()


def rotate(name, pitch, spread=0.0):
    bone = rig.pose.bones[name]
    inverse = bone.bone.matrix_local.to_3x3().inverted()
    bone.rotation_mode = "QUATERNION"
    bone.rotation_quaternion = (Quaternion(inverse @ Vector((0, 0, 1)), spread)
                                @ Quaternion(inverse @ Vector((1, 0, 0)), pitch))


report = json.loads((OUT / "gameplay_clips.json").read_text())
reference = json.loads((OUT / "reference_motion_bones.json").read_text())
rest = np.array([list(v.co) for v in body.data.vertices])
edges = np.array([list(e.vertices) for e in body.data.edges])
lengths = np.linalg.norm(rest[edges[:, 0]] - rest[edges[:, 1]], axis=1)
significant = lengths > 0.001
for track in list(rig.animation_data.nla_tracks):
    rig.animation_data.nla_tracks.remove(track)

for label in ("Jump", "Fall", "Plunge"):
    previous = bpy.data.actions.get("Game_" + label)
    if previous:
        bpy.data.actions.remove(previous)
    reset()
    action = bpy.data.actions.new("Game_" + label)
    action.use_fake_user = True
    action["authored_airborne"] = True
    rig.animation_data.action = action
    for frame in range(1, 14):
        scene.frame_set(frame)
        # Adapt the old airborne silhouette around the ARP anatomical axes.
        tuck = min((frame - 1) / 6.0, 1.0) if label == "Jump" else 1.0
        plunge = label == "Plunge"
        rotate("c_spine_02.x", -0.22 if plunge else -0.12)
        rotate("c_head.x", 0.10 if plunge else 0.04)
        for side, sign in (("l", -1), ("r", 1)):
            rotate("c_arm_fk." + side, -2.55 if plunge else (0.5 if label == "Jump" else 1.1), sign * (0.25 if plunge else 0.5))
            rotate("c_forearm_fk." + side, -0.55 if plunge else -0.18)
            thigh = -0.9 if plunge else (-0.55 if side == "l" else -0.25) * (0.65 + 0.35 * tuck)
            knee = 1.4 if plunge else (0.95 if side == "l" else 0.5) * (0.65 + 0.35 * tuck)
            rotate("c_thigh_fk." + side, thigh)
            rotate("c_leg_fk." + side, knee)
            rotate("c_foot_fk." + side, -0.12 if plunge else -0.08)
        for name in controls:
            bone = rig.pose.bones[name]
            for channel in ("location", "rotation_quaternion", "scale"):
                bone.keyframe_insert(data_path=channel, frame=frame, group=name)
        for side in ("l", "r"):
            for limb in ("hand", "foot"):
                rig.pose.bones["c_" + limb + "_ik." + side].keyframe_insert(data_path='["ik_fk_switch"]', frame=frame)
    checked = []
    for frame in (1, 4, 8, 13):
        scene.frame_set(frame)
        bpy.context.view_layer.update()
        evaluated = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
        mesh = evaluated.to_mesh()
        points = np.array([list(v.co) for v in mesh.vertices])
        evaluated.to_mesh_clear()
        assert np.isfinite(points).all()
        ratios = np.linalg.norm(points[edges[:, 0]] - points[edges[:, 1]], axis=1)[significant] / lengths[significant]
        checked.append({"frame": frame, "edge_ratio_p99": float(np.percentile(ratios, 99)),
                        "edge_ratio_max": float(ratios.max()), "min_z": float(points[:, 2].min())})
        np.save(OUT / ("reference_" + label + "_" + str(frame) + ".npy"), points)
        evaluated = rig.evaluated_get(bpy.context.evaluated_depsgraph_get())
        reference[label + ":" + str(frame)] = {b.name: [list(row) for row in b.matrix] for b in evaluated.pose.bones if b.bone.use_deform}
    report[label] = {"source": "Original player.gd FK silhouette adapted to ARP controls",
                     "frames": 13, "seconds": 0.4, "loop": label == "Fall",
                     "horizontal_root_locked": True, "vertical_root_locked": True,
                     "max_floor_correction_m": 0.0, "checked_frames": checked}
    print("AIRBORNE_AUTHORED", label, checked)

reset()
for label in report:
    track = rig.animation_data.nla_tracks.new()
    track.name = label
    action = bpy.data.actions["Game_" + label]
    strip = track.strips.new(label, 1, action)
    strip.action_slot = action.slots[0]
    strip.extrapolation = "NOTHING"
    strip.blend_type = "REPLACE"
    track.mute = True
scene.frame_set(1)
bpy.ops.object.select_all(action="DESELECT")
body.select_set(True)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
result = bpy.ops.export_scene.gltf(
    filepath=str(ROOT / "001/art/models/nezha_arp.glb"), export_format="GLB",
    use_selection=True, use_active_scene=True, export_skins=True, export_def_bones=True,
    export_all_influences=False, export_yup=True, export_animations=True,
    export_animation_mode="NLA_TRACKS", export_merge_animation="NLA_TRACK",
    export_force_sampling=True, export_frame_range=False,
    export_materials="EXPORT", export_image_format="AUTO", export_extras=False,
    export_cameras=False, export_lights=False)
assert result == {"FINISHED"}
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "art_source/nezha/nezha_arp.blend"), compress=True)
(OUT / "gameplay_clips.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
(OUT / "reference_motion_bones.json").write_text(json.dumps(reference), encoding="utf-8")
manifest_path = ROOT / "art_source/nezha/animations/manifest.json"
manifest = json.loads(manifest_path.read_text())
manifest["clips"] = report
manifest["airborne_revision"] = "2026-10-21: authored Jump/Fall/Plunge based on original game's FK poses; source FBX actions retained"
manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
print("AIRBORNE_EXPORT_COMPLETE", len(report))
