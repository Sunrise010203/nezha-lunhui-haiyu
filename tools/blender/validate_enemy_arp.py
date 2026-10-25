"""Reimport game GLBs and compare actual skinned vertices with ARP source samples."""
import hashlib
import json
from pathlib import Path
import bpy
import numpy as np
from mathutils import Matrix
from mathutils.kdtree import KDTree

ROOT = Path('E:/godot_game_by_fable')
OUT = ROOT / '_review/enemies_arp'
report = {}
for number, kind in enumerate(('crawler', 'shooter', 'divider', 'guard', 'turret', 'wraith', 'bomber', 'spawnling'), 1):
    code = f'{number:03d}'
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.fps = 30
    path = ROOT / '001/art/models/enemies_arp' / (code + '_' + kind + '.glb')
    bpy.ops.import_scene.gltf(filepath=str(path))
    body = next(o for o in scene.objects if o.type == 'MESH')
    rig = next(o for o in scene.objects if o.type == 'ARMATURE')
    rest = np.load(OUT / (code + '_rest.npy'))
    tree = KDTree(len(rest))
    for i, point in enumerate(rest):
        tree.insert(point, i)
    tree.balance()
    matches = [tree.find(body.matrix_world @ v.co) for v in body.data.vertices]
    assert max(d for _, _, d in matches) < .00001, code
    mapping = np.array([i for _, i, _ in matches])
    counts = [sum(g.weight > .00001 for g in v.groups) for v in body.data.vertices]
    assert min(counts) >= 1 and max(counts) <= 4, (code, min(counts), max(counts))
    assert max(abs(sum(g.weight for g in v.groups) - 1) for v in body.data.vertices) < .0001
    bones = json.loads((OUT / (code + '_rig.json')).read_text())['deform_bones']
    assert all(n in rig.data.bones for n in bones)
    clips = json.loads((OUT / (code + '_motion.json')).read_text())['clips']
    result = {'bones': len(bones), 'vertices': len(rest), 'exported_vertices': len(mapping), 'max_influences': max(counts), 'unweighted': 0, 'clips': {}}
    for label in ('Idle', 'Move', 'Windup', 'Attack', 'Recover', 'Hit'):
        action = bpy.data.actions[label]
        rig.animation_data.action = None
        for bone in rig.pose.bones:
            bone.matrix_basis = Matrix.Identity(4)
        rig.animation_data.action = action
        rig.animation_data.action_slot = action.slots[0]
        errors = []
        for sample in clips[label]['metrics']:
            frame = sample['frame']
            scene.frame_set(round(action.frame_range[0] + frame - 1))
            bpy.context.view_layer.update()
            ev = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
            mesh = ev.to_mesh()
            p = np.array([list(body.matrix_world @ v.co) for v in mesh.vertices])
            ev.to_mesh_clear()
            expected = np.load(OUT / f'{code}_{label}_{frame}.npy')[mapping]
            error = float(np.linalg.norm(p - expected, axis=1).max())
            assert np.isfinite(p).all() and error < .00015, (code, label, frame, error)
            errors.append(error)
        result['clips'][label] = {'samples': len(errors), 'max_error_m': max(errors)}
    original = Path('C:/Users/Sunrise/Downloads') / (code + '.glb')
    copied = ROOT / 'art_source/enemies/source' / (code + '.glb')
    assert hashlib.sha256(original.read_bytes()).digest() == hashlib.sha256(copied.read_bytes()).digest()
    result['source_sha256'] = hashlib.sha256(copied.read_bytes()).hexdigest()
    result['transition_errors_m'] = {}
    for before, after in (('Windup', 'Attack'), ('Attack', 'Recover')):
        end = clips[before]['frames']
        a = np.load(OUT / f'{code}_{before}_{end}.npy')
        b = np.load(OUT / f'{code}_{after}_1.npy')
        error = float(np.linalg.norm(a - b, axis=1).max())
        assert error < .0001, (code, before, after, error)
        result['transition_errors_m'][before + '-' + after] = error
    report[code] = result
    print('ENEMY_ROUNDTRIP_PASS', code, max(c['max_error_m'] for c in result['clips'].values()), flush=True)
(OUT / 'export_validation.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print('ALL_ENEMY_EXPORTS_PASS 8 models / 48 clips / 240 posed samples')
