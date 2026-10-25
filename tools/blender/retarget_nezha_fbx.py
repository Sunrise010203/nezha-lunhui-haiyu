"""Auto-Rig Pro Mixamo remap with rest-pose calibration; run in live Blender."""
import hashlib
import contextlib
import json
from pathlib import Path
import shutil
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector

ROOT = Path("E:/godot_game_by_fable")
OUT = ROOT / "_review/nezha_arp/animation"
SOURCE = ROOT / "art_source/nezha/animations"
SOURCE.mkdir(exist_ok=True)
scene = bpy.context.scene
rig = bpy.data.objects["Nezha_ARP_Rig"]
body = bpy.data.objects["Nezha_Body"]
area = next(a for a in bpy.context.screen.areas if a.type == "VIEW_3D")
region = next(r for r in area.regions if r.type == "WINDOW")
remap = sys.modules["bl_ext.user_default.auto_rig_pro.src.auto_rig_remap"]
FILES = json.loads((OUT / "source_inspection.json").read_text())
mapping = {"Hips": "c_root_master.x", "Spine1": "c_spine_01.x", "Spine2": "c_spine_02.x",
           "Neck": "c_neck.x", "Head": "c_head.x"}
for side, suffix in (("Left", "l"), ("Right", "r")):
    for source, target in (("Shoulder", "shoulder"), ("Arm", "arm_fk"), ("ForeArm", "forearm_fk"),
                           ("Hand", "hand_fk"), ("UpLeg", "thigh_fk"), ("Leg", "leg_fk"),
                           ("Foot", "foot_fk"), ("ToeBase", "toes_fk")):
        mapping[side + source] = "c_" + target + "." + suffix


def reset():
    rig.animation_data_clear()
    for bone in rig.pose.bones:
        bone.matrix_basis = Matrix.Identity(4)
    for side in ("l", "r"):
        for limb in ("hand", "foot"):
            rig.pose.bones["c_" + limb + "_ik." + side]["ik_fk_switch"] = 1.0
    rig.update_tag()
    bpy.context.view_layer.update()


names = list(FILES)
report = {}
with bpy.context.temp_override(area=area, region=region):
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    for name in names:
        reset()
        path = SOURCE / (name + ".fbx")
        if not path.exists():
            shutil.copy2(Path("C:/Users/Sunrise/Downloads") / path.name, path)
        objects_before = set(bpy.data.objects)
        bpy.ops.import_scene.fbx(filepath=str(path), use_anim=True)
        source = next(o for o in bpy.data.objects if o not in objects_before and o.type == "ARMATURE")
        source.name = "MotionSource"
        ratio = rig.data.bones["c_root_master.x"].head_local.z / (source.matrix_world @ source.data.bones["mixamorig:Hips"].head_local).z
        source.scale *= ratio
        bpy.context.view_layer.update()
        action = source.animation_data.action
        start, end = map(int, action.frame_range)
        scene.render.fps, scene.render.fps_base = 30, 1.0
        scene.source_rig, scene.target_rig = source.name, rig.name
        remap.save_source_action(source)
        bpy.ops.arp.build_bones_list()
        scene.arp_remap_allow_root_update = False
        for item in scene.bones_map_v2:
            item.name = mapping.get(item.source_bone.split(":")[-1], "None")
            item.set_as_root = item.source_bone.endswith(":Hips")
            item.ik = False
            item.location = False
        scene.arp_remap_allow_root_update = True
        # Match anatomical directions, not the arbitrary axes of the foot controls.
        bpy.ops.object.mode_set(mode="OBJECT")
        bpy.ops.object.select_all(action="DESELECT")
        source.select_set(True)
        bpy.context.view_layer.objects.active = source
        bpy.ops.arp.redefine_rest_pose(preserve=True, rest_pose="REST")
        for bone in sorted(source.pose.bones, key=lambda b: len(b.parent_recursive)):
            target_name = mapping.get(bone.name.split(":")[-1])
            if target_name is None:
                continue
            anatomical = target_name
            if "c_foot_fk." in target_name:
                anatomical = target_name.replace("c_foot_fk.", "foot.")
            target = rig.pose.bones[anatomical]
            current_direction = source.matrix_world.to_3x3() @ (bone.tail - bone.head)
            target_direction = rig.matrix_world.to_3x3() @ (target.tail - target.head)
            rotation = current_direction.normalized().rotation_difference(target_direction.normalized())
            world = source.matrix_world @ bone.matrix
            location = world.translation.copy()
            world = rotation.to_matrix().to_4x4() @ world
            world.translation = location
            bone.matrix = source.matrix_world.inverted() @ world
            bpy.context.view_layer.update()
        bpy.ops.arp.save_pose_rest()
        if name == names[0]:
            source_hand = source.data.bones["mixamorig:RightHand"]
            rest_world = source.matrix_world.to_3x3().normalized() @ source_hand.matrix_local.to_3x3()
            offsets = scene["rest_transf_offset"]["mixamorig:RightHand"]
            # Evaluate calibration without action to recover the mapped virtual weapon axis.
            saved_action = source.animation_data.action
            saved_slot = source.animation_data.action_slot
            source.animation_data.action = None
            for bname, transform in scene["rest_transf_offset"].items():
                pb = source.pose.bones[bname]
                pb.location, pb.rotation_mode, pb.rotation_euler, pb.rotation_quaternion = transform
            bpy.context.view_layer.update()
            calibrated = (source.matrix_world @ source.pose.bones[source_hand.name].matrix).to_3x3().normalized()
            axis = rig.data.bones["hand.r"].matrix_local.to_3x3().inverted() @ calibrated @ rest_world.inverted() @ Vector((0, 0, 1))
            (OUT / "weapon_socket.json").write_text(json.dumps({"shaft_axis_hand_local": list(axis.normalized()), "grip_hand_local": [0, 0.042, 0]}), encoding="utf-8")
            source.animation_data.action = saved_action
            source.animation_data.action_slot = saved_slot
            scene.frame_set(start)
        old = bpy.data.actions.get("Motion_" + name.replace(" ", "_"))
        if old:
            bpy.data.actions.remove(old)
        with (OUT / (name.replace(" ", "_") + "_remap.log")).open("w", encoding="utf-8") as log:
            with contextlib.redirect_stdout(log):
                bpy.ops.arp.retarget(frame_start=start, frame_end=end, fake_user_action=True,
                                     interpolation_type="LINEAR", clean_fk_rot=False)
        assert rig.animation_data and rig.animation_data.action
        result = rig.animation_data.action
        result.name = "Motion_" + name.replace(" ", "_")
        result.use_fake_user = True
        # Hips motion is retained here; gameplay-specific in-place/trim comes after inspection.
        report[name] = {"action": result.name, "frames": [start, end], "fps": 30,
                        "source_scale_ratio": ratio,
                        "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
        source.hide_set(True)
        source.hide_render = True
        scene.frame_set((start + end) // 2)
        target = Vector((0, 0, 0.82))
        scene.camera.location = target + Vector((0.7, -1, 0.05)).normalized() * 5
        scene.camera.rotation_euler = (target - scene.camera.location).to_track_quat("-Z", "Y").to_euler()
        scene.camera.data.ortho_scale = 2.2
        scene.render.resolution_x, scene.render.resolution_y = 800, 900
        # Temporarily recenter the camera on the animated pelvis for the diagnostic view.
        pelvis = rig.pose.bones["c_root_master.x"].head
        scene.camera.location.x += pelvis.x
        scene.camera.location.y += pelvis.y
        scene.render.filepath = str(OUT / (result.name + "_trial.png"))
        bpy.ops.render.render(write_still=True)
        bpy.ops.object.mode_set(mode="OBJECT")
        rig.animation_data.action = None
        for obj in list(bpy.data.objects):
            if obj not in objects_before:
                bpy.data.objects.remove(obj, do_unlink=True)
        if "rest_transf_offset" in scene:
            del scene["rest_transf_offset"]
        print("RETARGETED", name, result.name)
        (OUT / "retarget_report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    (OUT / "retarget_report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    reset()
    scene.frame_set(1)
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "art_source/nezha/nezha_motion_work.blend"), compress=True)
print("RETARGET_COMPLETE=" + json.dumps(report))
