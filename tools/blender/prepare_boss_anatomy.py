import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Matrix

ROOT = Path('E:/godot_game_by_fable')
sys.path.insert(0, str(ROOT / 'tools/blender'))
from build_enemy_arp import components

OUT = ROOT / '_review/bosses_arp'
SOURCE = ROOT / 'art_source/bosses'
report = {}
for i in range(1, 7):
    code = f'{i:02d}'
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(SOURCE / 'source' / (code + '.glb')))
    body = next(o for o in bpy.context.scene.objects if o.type == 'MESH')
    body.name = 'Boss_' + code + '_Body'
    body.data.transform(body.matrix_world)
    body.matrix_world = Matrix.Identity(4)
    body.data.transform(Matrix.Scale(1 / body.dimensions.z, 4) @ Matrix.Rotation(-math.pi / 2, 4, 'Z'))
    bm = bmesh.new()
    bm.from_mesh(body.data)
    before = len(bm.verts)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=.000002)
    bm.to_mesh(body.data)
    bm.free()
    body.data.update()
    p = np.array([list(v.co) for v in body.data.vertices])
    groups = components(body)
    np.save(OUT / (code + '_canonical.npy'), p)
    report[code] = dict(before=before, vertices=len(p), bounds=[p.min(0).tolist(), p.max(0).tolist()],
        components=[dict(count=len(g), center=p[g].mean(0).tolist(), bounds=[p[g].min(0).tolist(),p[g].max(0).tolist()]) for g in sorted(groups, key=len, reverse=True)[:40]])
    for image in bpy.data.images:
        if image.users and image.source == 'FILE' and not image.packed_file:
            image.pack()
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / (code + '_canonical.blend')), compress=True)
    print('CANONICAL', code, report[code]['bounds'], 'components', [len(g) for g in sorted(groups,key=len,reverse=True)[:15]], flush=True)
(OUT / 'anatomy.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
