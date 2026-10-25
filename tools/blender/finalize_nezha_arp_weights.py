"""Stabilize the front tabard and collar, then smooth only their boundaries."""
import json
from pathlib import Path

import bpy

OUT = Path("E:/godot_game_by_fable/_review/nezha_arp")
body = bpy.data.objects["Nezha_Body"]
topology = json.loads((OUT / "topology.json").read_text())
front = set(topology["islands"][15]["indices"])
groups = {g.name: g for g in body.vertex_groups}
for v in body.data.vertices:
    x, y, z = v.co
    collar = abs(x) < 0.095 and 1.22 < z < 1.31
    if v.index in front or collar:
        for group in body.vertex_groups:
            group.remove([v.index])
        if v.index in front:
            for name, value in (("root.x", 0.15), ("thigh_twist.l", 0.425), ("thigh_twist.r", 0.425)):
                groups[name].add([v.index], value, "REPLACE")
        else:
            t = min(1, max(0, (z - 1.23) / 0.08))
            t = t * t * (3 - 2 * t)
            groups["spine_02.x"].add([v.index], 1 - t, "REPLACE")
            groups["neck.x"].add([v.index], t, "REPLACE")

print("FRONT_AND_COLLAR_STABILIZED")
