"""Fit ARP references to the supplied character, then run ARP heat binding."""
import json
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path("E:/godot_game_by_fable")
OUT = ROOT / "_review/nezha_arp"
scene = bpy.context.scene
rig = bpy.data.objects["Nezha_ARP_Rig"]
body = bpy.data.objects["Nezha_Body"]
area = next(a for a in bpy.context.screen.areas if a.type == "VIEW_3D")
region = next(r for r in area.regions if r.type == "WINDOW")
report = {}

with bpy.context.temp_override(area=area, region=region):
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    rig.data.use_mirror_x = False
    bones = rig.data.edit_bones
    original = {b.name: (b.head.copy(), b.tail.copy()) for b in bones if "ref" in b.name}
    targets = {
        "root_ref.x": ((0, 0.005, 0.865), (0, 0.002, 0.99)),
        "spine_01_ref.x": ((0, 0.002, 0.99), (0, 0.005, 1.095)),
        "spine_02_ref.x": ((0, 0.005, 1.095), (0, 0.01, 1.245)),
        "neck_ref.x": ((0, 0.01, 1.245), (0, 0.002, 1.305)),
        "head_ref.x": ((0, 0.002, 1.305), (0, 0.002, 1.525)),
    }
    for side, sign in (("l", 1), ("r", -1)):
        def p(x, y, z):
            return (x * sign, y, z)

        shoulder = p(0.127, 0.002, 1.205)
        elbow = p(0.168, -0.006, 1.045)
        wrist = p(0.201, -0.028, 0.870)
        hand_end = p(0.207, -0.036, 0.786)
        hip = p(0.087, 0.008, 0.858)
        knee = p(0.111, -0.004, 0.485)
        ankle = p(0.128, 0.014, 0.093)
        ball = p(0.132, -0.061, 0.026)
        targets.update({
            "shoulder_ref." + side: (p(0.035, 0.008, 1.215), shoulder),
            "arm_ref." + side: (shoulder, elbow),
            "forearm_ref." + side: (elbow, wrist),
            "hand_ref." + side: (wrist, hand_end),
            "thigh_ref." + side: (hip, knee),
            "leg_ref." + side: (knee, ankle),
            "foot_ref." + side: (ankle, ball),
            "toes_ref." + side: (ball, p(0.134, -0.119, 0.022)),
            "foot_heel_ref." + side: (p(0.128, 0.042, 0.008), p(0.128, 0.018, 0.008)),
            "foot_bank_01_ref." + side: (p(0.157, 0.042, 0.008), p(0.157, 0.018, 0.008)),
            "foot_bank_02_ref." + side: (p(0.100, 0.042, 0.008), p(0.100, 0.018, 0.008)),
        })
        # The input has closed, fused fists. Fit references inside them, but skin
        # the fingers as a single hand rather than inventing finger articulation.
        old_head, old_tail = original["hand_ref." + side]
        new_head, new_tail = Vector(wrist), Vector(hand_end)
        rotation = (old_tail - old_head).rotation_difference(new_tail - new_head)
        for name, (head, tail) in original.items():
            if name.endswith("." + side) and any(
                name.startswith(prefix) for prefix in ("thumb", "index", "middle", "ring", "pinky")
            ):
                targets[name] = (
                    new_head + rotation @ ((head - old_head) * 0.45),
                    new_head + rotation @ ((tail - old_head) * 0.45),
                )

    for name, (head, tail) in targets.items():
        bones[name].head = head
        bones[name].tail = tail
    report["references"] = {
        name: {"head": list(bones[name].head), "tail": list(bones[name].tail)}
        for name in targets
    }
    bpy.ops.object.mode_set(mode="OBJECT")
    report["match_result"] = sorted(bpy.ops.arp.match_to_rig())
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    scene.arp_bind_engine = "HEAT_MAP"
    scene.arp_bind_split = False
    scene.arp_bind_scale_fix = True
    report["bind_result"] = sorted(bpy.ops.arp.bind_to_rig())
    report["bones"] = {
        b.name: {"head": list(b.head_local), "tail": list(b.tail_local), "deform": b.use_deform}
        for b in rig.data.bones
    }
    report["vertex_groups"] = [g.name for g in body.vertex_groups]
    report["unweighted"] = sum(not any(g.weight > 0.00001 for g in v.groups) for v in body.data.vertices)
    report["modifiers"] = [(m.name, m.type) for m in body.modifiers]
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "art_source/nezha/nezha_arp_work.blend"))

(OUT / "initial_bind.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print("BIND=" + json.dumps({k: v for k, v in report.items() if k not in ("references", "bones")}))
