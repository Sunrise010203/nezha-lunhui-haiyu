"""Normalize source orientation and inspect ARP reference bones for fitting."""
import json
import math
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix

ROOT = Path("E:/godot_game_by_fable")
OUT = ROOT / "_review/nezha_arp"
scene = bpy.context.scene
assert scene.name == "Nezha_ARP"
body = next(o for o in scene.objects if o.type == "MESH")
body.name = "Nezha_Body"
body.data.name = "Nezha_Surface"
transform = Matrix.Scale(1.6 / body.dimensions.z, 4) @ Matrix.Rotation(-math.pi / 2, 4, "Z")
body.data.transform(transform)
bm = bmesh.new()
bm.from_mesh(body.data)
before = len(bm.verts)
bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=0.000002)
bm.to_mesh(body.data)
bm.free()
body.data.update()
report = {"vertices_before_weld": before, "vertices_after_weld": len(body.data.vertices)}
area = next(a for a in bpy.context.screen.areas if a.type == "VIEW_3D")
region = next(r for r in area.regions if r.type == "WINDOW")
with bpy.context.temp_override(area=area, region=region):
    bpy.ops.arp.append_arp(rig_preset="human")
    rig = bpy.context.active_object
    rig.name = "Nezha_ARP_Rig"
    bpy.ops.object.mode_set(mode="EDIT")
    report["reference_bones"] = {
        b.name: {"head": list(b.head), "tail": list(b.tail), "parent": b.parent.name if b.parent else None}
        for b in rig.data.edit_bones if "ref" in b.name
    }
    bpy.ops.object.mode_set(mode="OBJECT")
report["body_bounds"] = [list(v) for v in body.bound_box]
(OUT / "reference_before_fit.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "art_source/nezha/nezha_arp_work.blend"))
print("PREPARED=" + json.dumps(report))
