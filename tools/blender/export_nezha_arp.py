"""Save editable ARP source, QA actions, and a clean skinned game interchange."""
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
assert not any(a.name.startswith("Game_") for a in bpy.data.actions), "Gameplay clips exist; use finalize_nezha_motions.py to preserve animated export."
if bpy.context.object and bpy.context.object.mode != "OBJECT":
    bpy.ops.object.mode_set(mode="OBJECT")


def reset():
    for bone in rig.pose.bones:
        bone.matrix_basis = Matrix.Identity(4)
    for side in ("l", "r"):
        for limb in ("hand", "foot"):
            rig.pose.bones["c_" + limb + "_ik." + side]["ik_fk_switch"] = 1.0
    rig.update_tag()
    bpy.context.view_layer.update()


checks = {
    "RaiseArms": [("c_arm_fk.l", (0, 1, 0), -105), ("c_arm_fk.r", (0, 1, 0), 105)],
    "ArmsOverhead": [("c_arm_fk.l", (0, 1, 0), -145), ("c_arm_fk.r", (0, 1, 0), 145)],
    "Elbows": [("c_arm_fk.l", (1, 0, 0), -40), ("c_forearm_fk.l", (1, 0, 0), -90), ("c_arm_fk.r", (1, 0, 0), -40), ("c_forearm_fk.r", (1, 0, 0), -90)],
    "LeftKnee": [("c_thigh_fk.l", (1, 0, 0), -60), ("c_leg_fk.l", (1, 0, 0), 95)],
    "RightKnee": [("c_thigh_fk.r", (1, 0, 0), -60), ("c_leg_fk.r", (1, 0, 0), 95)],
    "TorsoTwist": [("c_spine_01.x", (0, 0, 1), 20), ("c_spine_02.x", (0, 0, 1), 25)],
    "Turn": [("c_root_master.x", (0, 0, 1), 90)],
}

rig.animation_data_clear()
for action in list(bpy.data.actions):
    if action.name in {"QA_" + label for label in checks}:
        bpy.data.actions.remove(action)
reset()
report = {
    "source": "art_source/nezha/nezha_model.glb",
    "blender": bpy.app.version_string,
    "arp": "3.78.26",
    "height_m": 1.6,
    "facing_blender": "-Y; Z up",
    "facing_gltf": "+Z; Y up",
    "vertices": len(body.data.vertices),
    "triangles": sum(len(p.vertices) - 2 for p in body.data.polygons),
    "unweighted_vertices": sum(not any(g.weight > 1e-6 for g in v.groups) for v in body.data.vertices),
    "max_influences": max(sum(g.weight > 0.00001 for g in v.groups) for v in body.data.vertices),
    "max_weight_error": max(abs(sum(g.weight for g in v.groups) - 1) for v in body.data.vertices),
    "deform_groups": list(body.vertex_groups.keys()),
    "qa_actions": [],
}
assert report["unweighted_vertices"] == 0
assert report["max_influences"] <= 4
assert report["max_weight_error"] < 0.00001

# Keep evaluated deform transforms as a reference for export round-trip checks.
np.save(OUT / "reference_Rest.npy", np.array([list(v.co) for v in body.data.vertices]))
(OUT / "reference_rest_bones.json").write_text(json.dumps({
    b.name: [list(row) for row in b.matrix_local] for b in rig.data.bones if b.use_deform
}), encoding="utf-8")
roundtrip = {}
controls = {name for rotations in checks.values() for name, _, _ in rotations}
for name in controls:
    rig.pose.bones[name].rotation_mode = "QUATERNION"
for label, rotations in checks.items():
    reset()
    for name, axis, degrees in rotations:
        bone = rig.pose.bones[name]
        bone.rotation_mode = "QUATERNION"
        local_axis = bone.bone.matrix_local.to_3x3().inverted() @ Vector(axis)
        bone.rotation_quaternion = Quaternion(local_axis, math.radians(degrees))
        bpy.context.view_layer.update()
    evaluated_rig = rig.evaluated_get(bpy.context.evaluated_depsgraph_get())
    roundtrip[label] = {
        b.name: [list(row) for row in b.matrix]
        for b in evaluated_rig.pose.bones if b.bone.use_deform
    }
    evaluated = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
    evaluated_mesh = evaluated.to_mesh()
    np.save(OUT / ("reference_" + label + ".npy"), np.array([list(v.co) for v in evaluated_mesh.vertices]))
    evaluated.to_mesh_clear()

(OUT / "reference_deform_poses.json").write_text(json.dumps(roundtrip), encoding="utf-8")
reset()
bpy.ops.object.select_all(action="DESELECT")
body.select_set(True)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
export_path = ROOT / "001/art/models/nezha_arp.glb"
result = bpy.ops.export_scene.gltf(
    filepath=str(export_path), export_format="GLB", use_selection=True, use_active_scene=True,
    export_animations=False, export_skins=True, export_def_bones=True,
    export_all_influences=False, export_yup=True,
    export_materials="EXPORT", export_image_format="AUTO",
    export_extras=False, export_cameras=False, export_lights=False,
)
assert result == {"FINISHED"}
report["export"] = str(export_path)

for label, rotations in checks.items():
    action = bpy.data.actions.new("QA_" + label)
    action.use_fake_user = True
    rig.animation_data_create()
    rig.animation_data.action = action
    for frame, factor in ((1, 0), (16, 1), (32, 0)):
        reset()
        for name, axis, degrees in rotations:
            bone = rig.pose.bones[name]
            bone.rotation_mode = "QUATERNION"
            local_axis = bone.bone.matrix_local.to_3x3().inverted() @ Vector(axis)
            bone.rotation_quaternion = Quaternion(local_axis, math.radians(degrees * factor))
        for name in controls:
            rig.pose.bones[name].keyframe_insert(data_path="rotation_quaternion", frame=frame, group=name)
        for side in ("l", "r"):
            for limb in ("hand", "foot"):
                rig.pose.bones["c_" + limb + "_ik." + side].keyframe_insert(data_path='["ik_fk_switch"]', frame=frame)
    rig.animation_data.action = None
    report["qa_actions"].append(action.name)
reset()
scene.frame_start, scene.frame_end = 1, 32
scene.frame_set(1)
rig["source_model"] = "nezha_model.glb"
rig["rigging_tool"] = "Auto-Rig Pro 3.78.26"
rig["notes"] = "Closed fists: rigid hand skinning. QA actions are source-only; no animation exported."
body["skin_influences"] = 4
for image in bpy.data.images:
    if image.source == "FILE" and image.packed_file is None:
        image.pack()

area = next(a for a in bpy.context.screen.areas if a.type == "VIEW_3D")
area.spaces.active.shading.type = "SOLID"
area.spaces.active.shading.color_type = "TEXTURE"
area.spaces.active.region_3d.view_distance = 2.5
area.spaces.active.region_3d.view_location = Vector((0, 0, 0.82))
area.spaces.active.region_3d.view_rotation = Quaternion((0.92388, 0.382683, 0, 0))
with bpy.context.temp_override(area=area, region=next(r for r in area.regions if r.type == "WINDOW")):
    bpy.ops.object.mode_set(mode="POSE")
    bpy.ops.pose.select_all(action="DESELECT")

source_path = ROOT / "art_source/nezha/nezha_arp.blend"
bpy.ops.wm.save_as_mainfile(filepath=str(source_path), compress=True)
report["blend"] = str(source_path)
(OUT / "delivery.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print("DELIVERY=" + json.dumps(report))
