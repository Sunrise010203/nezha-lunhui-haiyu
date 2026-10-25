"""Bake gameplay clips, remove root drift, inspect skin, and export named NLA clips."""
import json
from pathlib import Path

import bpy
import numpy as np
from mathutils import Matrix, Vector

ROOT = Path("E:/godot_game_by_fable")
OUT = ROOT / "_review/nezha_arp/animation"
scene = bpy.context.scene
rig = bpy.data.objects["Nezha_ARP_Rig"]
body = bpy.data.objects["Nezha_Body"]
assert "Game_Plunge" not in bpy.data.actions, "Use revise_nezha_airborne.py to preserve the authored airborne poses."
if bpy.context.object and bpy.context.object.mode != "OBJECT":
    bpy.ops.object.mode_set(mode="OBJECT")
clips = {
    "Idle": ("Breathing Idle", 1, 299, True),
    "FightIdle": ("Fight Idle", 1, 72, True),
    "Run": ("Run Forward", 1, 28, True),
    "Jump": ("Jumping", 17, 27, False),
    "Fall": ("Fall A Loop", 1, 33, True),
    "Land": ("Falling To Landing", 9, 33, False),
    "Roll": ("Quick Roll To Run", 1, 39, False),
    "Stab": ("Bayonet Stab", 22, 52, False),
    "Slash": ("Stable Sword Outward Slash", 18, 42, False),
    "ThrustSlash": ("Thrust Slash", 19, 45, False),
    "UpwardThrust": ("Upward Thrust", 11, 49, False),
    "Hit": ("Zombie Reaction Hit", 5, 32, False),
    "Death": ("Falling Back Death", 1, 79, False),
}
controls = ["c_root_master.x", "c_spine_01.x", "c_spine_02.x", "c_neck.x", "c_head.x"]
for side in ("l", "r"):
    controls.extend("c_" + limb + "." + side for limb in (
        "shoulder", "arm_fk", "forearm_fk", "hand_fk", "thigh_fk", "leg_fk", "foot_fk", "toes_fk"))
rig.animation_data_create()
for track in list(rig.animation_data.nla_tracks):
    rig.animation_data.nla_tracks.remove(track)
for name in clips:
    previous = bpy.data.actions.get("Game_" + name)
    if previous:
        bpy.data.actions.remove(previous)


def reset():
    rig.animation_data.action = None
    for bone in rig.pose.bones:
        bone.matrix_basis = Matrix.Identity(4)
    for side in ("l", "r"):
        for limb in ("hand", "foot"):
            rig.pose.bones["c_" + limb + "_ik." + side]["ik_fk_switch"] = 1.0
    rig.update_tag()
    bpy.context.view_layer.update()


def vertices():
    evaluated = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = evaluated.to_mesh()
    coords = np.empty(len(mesh.vertices) * 3, dtype=np.float32)
    mesh.vertices.foreach_get("co", coords)
    evaluated.to_mesh_clear()
    return coords.reshape(-1, 3)


rest = np.array([list(v.co) for v in body.data.vertices])
edges = np.array([list(e.vertices) for e in body.data.edges])
rest_lengths = np.linalg.norm(rest[edges[:, 0]] - rest[edges[:, 1]], axis=1)
significant = rest_lengths > 0.001
report = {}
reference = {}
for label, (source_name, start, end, loop) in clips.items():
    reset()
    source = bpy.data.actions["Motion_" + source_name.replace(" ", "_")]
    rig.animation_data.action = source
    rig.animation_data.action_slot = source.slots[0]
    snapshots = []
    min_z = []
    max_correction = 0.0
    for frame in range(start, end + 1):
        scene.frame_set(frame)
        root = rig.pose.bones["c_root_master.x"]
        matrix = root.matrix.copy()
        matrix.translation.x = 0.0
        matrix.translation.y = 0.005
        if label in ("Jump", "Fall"):
            matrix.translation.z = 0.865
        root.matrix = matrix
        bpy.context.view_layer.update()
        points = vertices()
        correction = 0.0
        if label not in ("Jump", "Fall"):
            correction = max(0.0, -float(points[:, 2].min()) + 0.002)
            matrix = root.matrix.copy()
            matrix.translation.z += correction
            root.matrix = matrix
            bpy.context.view_layer.update()
        max_correction = max(max_correction, correction)
        min_z.append(float(points[:, 2].min()) + correction)
        snapshots.append({name: rig.pose.bones[name].matrix_basis.copy() for name in controls})
    reset()
    action = bpy.data.actions.new("Game_" + label)
    action.use_fake_user = True
    rig.animation_data.action = action
    for index, snapshot in enumerate(snapshots, 1):
        for name, matrix in snapshot.items():
            bone = rig.pose.bones[name]
            bone.rotation_mode = "QUATERNION"
            bone.matrix_basis = matrix
            for channel in ("location", "rotation_quaternion", "scale"):
                bone.keyframe_insert(data_path=channel, frame=index, group=name)
        for side in ("l", "r"):
            for limb in ("hand", "foot"):
                rig.pose.bones["c_" + limb + "_ik." + side].keyframe_insert(data_path='["ik_fk_switch"]', frame=index)
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for key in curve.keyframe_points:
                        key.interpolation = "LINEAR"
    last = end - start + 1
    checked = []
    for frame in sorted({1, max(1, last // 3), max(1, last * 2 // 3), last}):
        scene.frame_set(frame)
        points = vertices()
        assert np.isfinite(points).all(), label
        lengths = np.linalg.norm(points[edges[:, 0]] - points[edges[:, 1]], axis=1)
        ratios = lengths[significant] / rest_lengths[significant]
        checked.append({"frame": frame, "edge_ratio_p99": float(np.percentile(ratios, 99)),
                        "edge_ratio_max": float(ratios.max()), "min_z": float(points[:, 2].min())})
        evaluated = rig.evaluated_get(bpy.context.evaluated_depsgraph_get())
        reference[label + ":" + str(frame)] = {b.name: [list(row) for row in b.matrix] for b in evaluated.pose.bones if b.bone.use_deform}
        np.save(OUT / ("reference_" + label + "_" + str(frame) + ".npy"), points)
        target = Vector((0, 0, 0.8))
        scene.camera.location = target + Vector((0.7, -1, 0.06)).normalized() * 5
        scene.camera.rotation_euler = (target - scene.camera.location).to_track_quat("-Z", "Y").to_euler()
        scene.camera.data.ortho_scale = 2.05
        scene.render.resolution_x, scene.render.resolution_y = 640, 720
        scene.render.filepath = str(OUT / (label + "_" + str(frame) + ".png"))
        bpy.ops.render.render(write_still=True)
    report[label] = {"fbx": source_name + ".fbx", "source_range": [start, end],
                     "frames": last, "seconds": (last - 1) / 30, "loop": loop,
                     "horizontal_root_locked": True, "max_floor_correction_m": max_correction,
                     "checked_frames": checked}
    print("PREPARED", label, report[label]["seconds"])
    (OUT / "gameplay_clips.json").write_text(json.dumps(report, indent=2), encoding="utf-8")

(OUT / "reference_motion_bones.json").write_text(json.dumps(reference), encoding="utf-8")
reset()
scene.render.fps, scene.render.fps_base = 30, 1.0
for label in clips:
    action = bpy.data.actions["Game_" + label]
    track = rig.animation_data.nla_tracks.new()
    track.name = label
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
    export_cameras=False, export_lights=False,
)
assert result == {"FINISHED"}
reset()
scene.frame_start, scene.frame_end = 1, 299
scene.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "art_source/nezha/nezha_arp.blend"), compress=True)
manifest = {"retarget_tool": "Auto-Rig Pro 3.78.26", "fps": 30, "mapping": "Mixamo to ARP controls to 67 deform bones",
            "clips": report, "weapon_socket": json.loads((OUT / "weapon_socket.json").read_text())}
(ROOT / "art_source/nezha/animations/manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
print("MOTION_EXPORT_COMPLETE", len(clips))
