"""Measure welded components and lateral/height sections in canonical coordinates."""
import json
import math
import sys
from pathlib import Path
import bmesh
import bpy
import numpy as np
from mathutils import Matrix

ROOT = Path("E:/godot_game_by_fable")
OUT = ROOT / "_review/enemies_arp"
codes = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [f'{n:03d}' for n in range(1, 9)]
report_path = OUT / 'anatomy.json'
report = json.loads(report_path.read_text()) if report_path.exists() else {}
for code in codes:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(ROOT / "art_source/enemies/source" / (code + ".glb")))
    body = next(o for o in bpy.context.scene.objects if o.type == "MESH")
    body.data.transform(body.matrix_world)
    body.matrix_world = Matrix.Identity(4)
    body.data.transform(Matrix.Scale(1 / body.dimensions.z, 4) @ Matrix.Rotation(-math.pi / 2, 4, "Z"))
    bm = bmesh.new()
    bm.from_mesh(body.data)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=0.000002)
    bm.verts.ensure_lookup_table()
    visited = set()
    components = []
    for v in bm.verts:
        if v.index in visited:
            continue
        stack, indices = [v], []
        visited.add(v.index)
        while stack:
            current = stack.pop()
            indices.append(current.index)
            for e in current.link_edges:
                other = e.other_vert(current)
                if other.index not in visited:
                    visited.add(other.index)
                    stack.append(other)
        if len(indices) > 15:
            points = np.array([list(bm.verts[i].co) for i in indices])
            components.append({"vertices": len(indices), "min": points.min(0).tolist(), "max": points.max(0).tolist(), "center": points.mean(0).tolist()})
    points = np.array([list(v.co) for v in bm.verts])
    np.save(OUT / (code + "_canonical_vertices.npy"), points)
    slices = {}
    for z in (0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9):
        section = points[np.abs(points[:, 2] - z) < 0.015]
        slices[str(z)] = {"n": len(section), "x_range": np.percentile(section[:, 0], [0, 10, 25, 50, 75, 90, 100]).tolist(), "y_range": np.percentile(section[:, 1], [0, 10, 25, 50, 75, 90, 100]).tolist()} if len(section) else {}
    report[code] = {"welded_vertices": len(points), "components": sorted(components, key=lambda c: -c["vertices"])[:40], "slices": slices}
    bm.free()
(OUT / "anatomy.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print("ANATOMY_COMPLETE")
