"""Apply exportable albedo correction without changing geometry or skinning."""
import hashlib
import json
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path("E:/godot_game_by_fable")
OUT = ROOT / "_review/nezha_arp/appearance"
body = bpy.data.objects["Nezha_Body"]
rig = bpy.data.objects["Nezha_ARP_Rig"]
scene = bpy.context.scene


def signature():
    values = {
        "vertices": [list(v.co) for v in body.data.vertices],
        "weights": [[(g.group, g.weight) for g in v.groups] for v in body.data.vertices],
        "bones": [(b.name, list(b.head_local), list(b.tail_local)) for b in rig.data.bones],
    }
    return hashlib.sha256(json.dumps(values).encode()).hexdigest()


before = signature()
material = body.data.materials[0]
bsdf = next(n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
node = bsdf.inputs["Base Color"].links[0].from_node
assert node.type == "TEX_IMAGE"
original = node.image.name
image = bpy.data.images.load(str(ROOT / "art_source/nezha/textures/Nezha_Albedo_Bright.png"), check_existing=True)
image.name = "Nezha_Albedo_Bright"
image.colorspace_settings.name = "sRGB"
image.pack()
node.image = image
material.node_tree.nodes.active = node
assert signature() == before
report = {"previous_image": original, "image": image.name,
          "geometry_skin_bones_sha256_before": before,
          "geometry_skin_bones_sha256_after": signature(),
          "geometry_skin_bones_unchanged": True, "exposure": scene.view_settings.exposure}
for label, direction in (("front", (0, -1, 0)), ("three_quarter", (0.65, -1, 0.05))):
    target = Vector((0, 0, 0.82))
    scene.camera.location = target + Vector(direction).normalized() * 5
    scene.camera.rotation_euler = (target - scene.camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = str(OUT / ("after_" + label + ".png"))
    bpy.ops.render.render(write_still=True)
scene.camera.location = (0, -5, 0.82)
scene.camera.rotation_euler = (Vector((0, 0, 0.82)) - scene.camera.location).to_track_quat("-Z", "Y").to_euler()
(OUT / "appearance_validation.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print(json.dumps(report))
