"""Read material connections and save a repeatable appearance baseline."""
import json
from pathlib import Path

import bpy
from mathutils import Vector

out = Path("E:/godot_game_by_fable/_review/nezha_arp/appearance")
out.mkdir(exist_ok=True)
scene = bpy.context.scene
body = bpy.data.objects["Nezha_Body"]
report = {"engine": scene.render.engine, "view": scene.view_settings.view_transform,
          "exposure": scene.view_settings.exposure, "materials": []}
for material in body.data.materials:
    info = {"name": material.name, "nodes": []}
    for node in material.node_tree.nodes:
        data = {"name": node.name, "type": node.type}
        if node.type == "TEX_IMAGE" and node.image:
            data.update(image=node.image.name, size=list(node.image.size),
                        colorspace=node.image.colorspace_settings.name)
        if node.type == "BSDF_PRINCIPLED":
            data["inputs"] = {s.name: str(s.default_value) for s in node.inputs if not s.is_linked}
        info["nodes"].append(data)
    info["links"] = [[l.from_node.name, l.from_socket.name, l.to_node.name, l.to_socket.name]
                     for l in material.node_tree.links]
    report["materials"].append(info)
(out / "material_before.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
scene.render.engine = "BLENDER_WORKBENCH"
scene.render.resolution_x, scene.render.resolution_y = 800, 1000
scene.render.resolution_percentage = 100
scene.display.shading.color_type = "TEXTURE"
scene.display.shading.show_cavity = False
scene.display.shading.show_shadows = True
scene.camera.data.ortho_scale = 1.86
target = Vector((0, 0, 0.82))
scene.camera.location = (0, -5, 0.82)
scene.camera.rotation_euler = (target - scene.camera.location).to_track_quat("-Z", "Y").to_euler()
scene.render.filepath = str(out / "before_front.png")
bpy.ops.render.render(write_still=True)
print(json.dumps(report))
