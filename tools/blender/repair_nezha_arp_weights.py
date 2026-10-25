"""Repair anatomically invalid ARP weights on close limbs and loose armor."""
import json
from pathlib import Path

import bpy

ROOT = Path("E:/godot_game_by_fable")
OUT = ROOT / "_review/nezha_arp"
body = bpy.data.objects["Nezha_Body"]
rig = bpy.data.objects["Nezha_ARP_Rig"]
topology = json.loads((OUT / "topology.json").read_text(encoding="utf-8"))
island_of = {}
for island, component in enumerate(topology["islands"]):
    for index in component["indices"]:
        island_of[index] = island
names = {g.index: g.name for g in body.vertex_groups}
weights = [{names[g.group]: g.weight for g in v.groups} for v in body.data.vertices]
fixed = []


def ramp(a, b, value):
    t = min(1.0, max(0.0, (value - a) / (b - a)))
    return t * t * (3.0 - 2.0 * t)


def mix(a, b, t):
    return {a: 1.0 - t, b: t}


def torso(z):
    if z < 1.01:
        return mix("root.x", "spine_01.x", ramp(0.945, 1.035, z))
    if z < 1.15:
        return mix("spine_01.x", "spine_02.x", ramp(1.025, 1.14, z))
    if z < 1.28:
        return mix("spine_02.x", "neck.x", ramp(1.23, 1.29, z))
    return mix("neck.x", "head.x", ramp(1.275, 1.325, z))


def hip_weights(x, z):
    hem = ramp(0.99, 0.79, z)
    left = ramp(-0.065, 0.065, x)
    return {"root.x": 1 - hem, "thigh_twist.l": hem * left, "thigh_twist.r": hem * (1 - left)}


for v, initial in zip(body.data.vertices, weights):
    x, y, z = v.co
    ax = abs(x)
    side = ".l" if x > 0 else ".r"
    island = island_of[v.index]
    component = topology["islands"][island]
    lo, hi = component["min"], component["max"]
    if z > 1.325 or lo[2] > 1.30:
        result = {"head.x": 1.0}
    elif lo[2] > 0.75 and hi[2] < 0.90 and component["count"] > 1000:
        result = {"hand" + side: 1.0}
    elif lo[2] > 0.85 and hi[2] < 1.0 and component["count"] > 1000:
        result = {"forearm_twist" + side: 1.0}
    elif lo[2] > 1.08 and hi[2] < 1.14 and ax > 0.10:
        result = {"c_arm_twist_offset" + side: 1.0}
    elif island in (8, 19):
        result = {"root.x": 1.0}
    elif island in (1, 7):
        result = torso(z)
        amount = ramp(0.075, 0.165, ax) * ramp(1.17, 1.23, z) * 0.80
        result = {k: w * (1 - amount) for k, w in result.items()}
        result["c_arm_twist_offset" + side] = amount
    elif z > 0.85 and sum(w for k, w in initial.items() if any(k.startswith(prefix) for prefix in ("arm_stretch", "c_arm_twist_offset", "forearm_stretch", "forearm_twist"))) > 0.10:
        allowed = {
            "arm_stretch" + side, "c_arm_twist_offset" + side,
            "forearm_stretch" + side, "forearm_twist" + side, "hand" + side,
        }
        if z > 1.13:
            allowed.update(("spine_02.x", "shoulder" + side))
        result = {k: w for k, w in initial.items() if k in allowed}
    elif island in (23, 24) or 0.64 < z < 0.96:
        result = hip_weights(x, z)
    elif z > 0.94 and z < 1.28:
        allowed = {
            "arm_stretch" + side, "c_arm_twist_offset" + side,
            "forearm_stretch" + side, "forearm_twist" + side, "hand" + side,
            "root.x", "spine_01.x", "spine_02.x", "neck.x", "shoulder" + side,
        }
        result = {k: w for k, w in initial.items() if k in allowed}
        if sum(result.values()) < 0.01:
            result = torso(z)
    elif z > 0.96:
        result = torso(z)
    elif z < 0.94:
        allowed = {
            "root.x", "thigh_stretch" + side, "thigh_twist" + side,
            "leg_stretch" + side, "leg_twist" + side, "foot" + side, "toes_01" + side,
        }
        result = {k: w for k, w in initial.items() if k in allowed}
        if sum(result.values()) < 0.01:
            result = mix("root.x", "thigh_twist" + side, ramp(0.92, 0.68, z))
    else:
        result = torso(z)
    result = dict(sorted(((k, w) for k, w in result.items() if w > 0.0001), key=lambda item: -item[1])[:4])
    total = sum(result.values())
    assert total > 0, v.index
    fixed.append({k: w / total for k, w in result.items()})

body.vertex_groups.clear()
for name in sorted({name for w in fixed for name in w}):
    group = body.vertex_groups.new(name=name)
    for i, vertex_weights in enumerate(fixed):
        if name in vertex_weights:
            group.add([i], vertex_weights[name], "REPLACE")

modifier = next(m for m in body.modifiers if m.type == "ARMATURE")
modifier.use_deform_preserve_volume = False
report = {
    "vertices": len(fixed), "unweighted": sum(not w for w in fixed),
    "max_influences": max(len(w) for w in fixed),
    "max_normalization_error": max(abs(sum(w.values()) - 1) for w in fixed),
    "groups": [g.name for g in body.vertex_groups],
    "linear_skinning": True,
}
(OUT / "weight_repair.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "art_source/nezha/nezha_arp_work.blend"))
print("REPAIRED=" + json.dumps(report))
