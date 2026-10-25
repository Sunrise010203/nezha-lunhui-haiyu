"""Validate exported skin by reproducing source deform transforms after import."""
import json
from pathlib import Path

import bpy
import numpy as np
from mathutils import Matrix
from mathutils.kdtree import KDTree

ROOT = Path("E:/godot_game_by_fable")
OUT = ROOT / "_review/nezha_arp"
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT / "001/art/models/nezha_arp.glb"))
body = next(o for o in bpy.context.scene.objects if o.type == "MESH")
rig = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
source_rest = np.load(OUT / "reference_Rest.npy")
rest_bones = json.loads((OUT / "reference_rest_bones.json").read_text())
poses = json.loads((OUT / "reference_deform_poses.json").read_text())
tree = KDTree(len(source_rest))
for i, point in enumerate(source_rest):
    tree.insert(point, i)
tree.balance()
matches = [tree.find(body.matrix_world @ v.co) for v in body.data.vertices]
mapping = np.array([index for _, index, _ in matches])
report = {
    "meshes": sum(o.type == "MESH" and any(m.type == "ARMATURE" for m in o.modifiers) for o in bpy.context.scene.objects),
    "armatures": sum(o.type == "ARMATURE" for o in bpy.context.scene.objects),
    "imported_vertices": len(body.data.vertices),
    "max_rest_position_error_m": max(distance for _, _, distance in matches),
    "unweighted_vertices": sum(not any(g.weight > 1e-6 for g in v.groups) for v in body.data.vertices),
    "poses": {},
}
print("IMPORT_STRUCTURE=" + json.dumps({"report": report, "objects": [(o.name, o.type) for o in bpy.context.scene.objects]}))
assert report["meshes"] == report["armatures"] == 1
assert report["max_rest_position_error_m"] < 0.00001
assert report["unweighted_vertices"] == 0


def depth(bone):
    return len(bone.parent_recursive)


for name, pose in poses.items():
    for bone in rig.pose.bones:
        bone.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
    for bone in sorted(rig.pose.bones, key=depth):
        if bone.name in pose:
            delta = Matrix(pose[bone.name]) @ Matrix(rest_bones[bone.name]).inverted()
            bone.matrix = delta @ bone.bone.matrix_local
            bpy.context.view_layer.update()
    evaluated = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = evaluated.to_mesh()
    points = np.array([list(body.matrix_world @ v.co) for v in mesh.vertices])
    evaluated.to_mesh_clear()
    reference = np.load(OUT / ("reference_" + name + ".npy"))[mapping]
    errors = np.linalg.norm(points - reference, axis=1)
    report["poses"][name] = {"max_error_m": float(errors.max()), "mean_error_m": float(errors.mean())}
    assert errors.max() < 0.0001, (name, errors.max())

report["passed"] = True
(OUT / "export_validation.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print("EXPORT_VALIDATION=" + json.dumps(report))
