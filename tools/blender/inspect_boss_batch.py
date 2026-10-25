"""Preserve supplied sources, identify axes and topology before fitting ARP."""
import hashlib
import json
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Vector

ROOT = Path('E:/godot_game_by_fable')
OUT = ROOT / '_review/bosses_arp'
SOURCE = ROOT / 'art_source/bosses/source'
OUT.mkdir(parents=True, exist_ok=True)
SOURCE.mkdir(parents=True, exist_ok=True)
report = {}
for n in range(1, 7):
    code = f'{n:02d}'
    original = Path('C:/Users/Sunrise/Downloads') / (code + '.glb')
    source = SOURCE / original.name
    digest = hashlib.sha256(original.read_bytes()).hexdigest()
    if source.exists():
        assert hashlib.sha256(source.read_bytes()).hexdigest() == digest
    else:
        source.write_bytes(original.read_bytes())
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(source))
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    points = np.array([list(o.matrix_world @ v.co) for o in meshes for v in o.data.vertices])
    low, high = points.min(0), points.max(0)
    report[code] = dict(sha256=digest, bounds=[low.tolist(), high.tolist()], vertices=len(points),
        triangles=sum(len(o.data.loop_triangles) for o in meshes),
        meshes=[dict(name=o.name, vertices=len(o.data.vertices), groups=len(o.vertex_groups)) for o in meshes],
        armatures=[o.name for o in bpy.context.scene.objects if o.type == 'ARMATURE'])
    np.save(OUT / (code + '_raw.npy'), points)
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_WORKBENCH'
    scene.display.shading.color_type = 'TEXTURE'
    scene.display.shading.light = 'STUDIO'
    scene.display.shading.show_cavity = True
    scene.display.shading.background_type = 'WORLD'
    scene.world.color = (0.12, 0.12, 0.12)
    scene.render.resolution_x, scene.render.resolution_y = 520, 600
    scene.render.resolution_percentage = 100
    camera_data = bpy.data.cameras.new('InspectionCamera')
    camera = bpy.data.objects.new('InspectionCamera', camera_data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    camera_data.type = 'ORTHO'
    center = Vector((low + high) / 2)
    size = float(max(high - low))
    camera_data.ortho_scale = size * 1.22
    for label, direction in [('xplus', (1, 0, 0)), ('yminus', (0, -1, 0)), ('xminus', (-1, 0, 0))]:
        camera.location = center + Vector(direction) * size * 4
        camera.rotation_euler = (center - camera.location).to_track_quat('-Z', 'Y').to_euler()
        scene.render.filepath = str(OUT / (code + '_' + label + '.png'))
        bpy.ops.render.render(write_still=True)
    print('BOSS_INSPECTED', code, report[code], flush=True)
(OUT / 'source_inspection.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
