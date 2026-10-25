"""Inventory welded islands and joint cross sections for local weight repair."""
import json
from pathlib import Path

import bmesh
import bpy
import numpy as np

body = bpy.data.objects["Nezha_Body"]
bm = bmesh.new()
bm.from_mesh(body.data)
bm.verts.ensure_lookup_table()
seen = set()
components = []
for seed in bm.verts:
    if seed.index in seen:
        continue
    todo = [seed]
    seen.add(seed.index)
    indices = []
    while todo:
        v = todo.pop()
        indices.append(v.index)
        for e in v.link_edges:
            other = e.other_vert(v)
            if other.index not in seen:
                seen.add(other.index)
                todo.append(other)
    points = np.array([list(bm.verts[i].co) for i in indices])
    components.append({"indices": indices, "count": len(indices), "min": points.min(axis=0).tolist(), "max": points.max(axis=0).tolist(), "center": points.mean(axis=0).tolist()})
components.sort(key=lambda x: -x["count"])
report = {"nonmanifold_edges": sum(not e.is_manifold for e in bm.edges), "islands": components}
bm.free()
coords = np.array([list(v.co) for v in body.data.vertices])
report["sections"] = {}
for z in (0.08, 0.16, 0.3, 0.45, 0.5, 0.7, 0.8, 0.86, 0.92, 1.05, 1.20):
    pts = coords[(abs(coords[:, 2] - z) < 0.008) & (coords[:, 0] > 0)]
    report["sections"][str(z)] = {"min": pts.min(axis=0).tolist(), "max": pts.max(axis=0).tolist(), "median": np.median(pts, axis=0).tolist()}
Path("E:/godot_game_by_fable/_review/nezha_arp/topology.json").write_text(json.dumps(report), encoding="utf-8")
print(json.dumps({"nonmanifold_edges": report["nonmanifold_edges"], "islands": [{k: v for k, v in c.items() if k != "indices"} for c in components[:45]], "sections": report["sections"]}))
