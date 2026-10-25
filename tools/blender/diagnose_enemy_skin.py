"""Inspect posed bone transforms and the worst stretched edges."""
import json
from pathlib import Path
import sys
import bpy
import numpy as np
from mathutils import Matrix

ROOT = Path('E:/godot_game_by_fable')
codes = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else ['004', '007']
for code in codes:
    path = next((ROOT / 'art_source/enemies').glob(code + '_*.blend'))
    bpy.ops.wm.open_mainfile(filepath=str(path))
    rig = bpy.data.objects['Enemy_' + code + '_ARP_Rig']
    body = bpy.data.objects['Enemy_' + code + '_Body']
    rig.animation_data_create()
    rig.animation_data.action = None
    for track in list(rig.animation_data.nla_tracks):
        rig.animation_data.nla_tracks.remove(track)
    rest = np.array([list(v.co) for v in body.data.vertices])
    edges = np.array([list(e.vertices) for e in body.data.edges])
    lengths = np.linalg.norm(rest[edges[:, 0]] - rest[edges[:, 1]], axis=1)
    print('RIG', code, rig.data.pose_position, 'MODIFIERS', [(m.name, m.type) for m in body.modifiers])
    if code == '004':
        for n in ('c_hand_ik.l', 'arm_stretch.l', 'arm_fk.l', 'arm_ik.l'):
            b = rig.pose.bones.get(n)
            if b:
                print('CONTROL', n, dict(b.items()), [(c.name, c.type, c.influence, getattr(c, 'subtarget', '')) for c in b.constraints])
        for d in rig.animation_data.drivers:
            if 'ik_fk' in d.driver.expression or ('arm_stretch.l' in d.data_path):
                print('DRIVER', d.data_path, d.driver.expression, d.driver.is_valid, [(v.name, [(t.data_path, str(t.id)) for t in v.targets]) for v in d.driver.variables])
    for label in ('Idle', 'QA_Raise', 'QA_Bend', 'QA_Turn'):
        rig.animation_data.action = None
        for bone in rig.pose.bones:
            bone.matrix_basis = Matrix.Identity(4)
        action = bpy.data.actions['Enemy_' + code + '_' + label]
        rig.animation_data.action = action
        rig.animation_data.action_slot = action.slots[0]
        rig.update_tag()
        bpy.context.scene.frame_set(3)
        bpy.context.scene.frame_set(2)
        bpy.context.view_layer.update()
        ev = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
        mesh = ev.to_mesh()
        points = np.array([list(v.co) for v in mesh.vertices])
        ev.to_mesh_clear()
        ratios = np.linalg.norm(points[edges[:, 0]] - points[edges[:, 1]], axis=1) / np.maximum(lengths, .001)
        print('POSE', label, 'max', ratios.max(), 'p99', np.percentile(ratios, 99))
        for ei in np.argsort(ratios)[-3:]:
            print('EDGE', ratios[ei], [(rest[vi].tolist(), points[vi].tolist(), [(body.vertex_groups[g.group].name, round(g.weight, 3)) for g in body.data.vertices[vi].groups]) for vi in edges[ei]])
        if code == '004':
            for name in ('c_root_master.x', 'root.x', 'c_arm_fk.l', 'arm_stretch.l', 'c_thigh_fk.l', 'thigh_stretch.l', 'c_traj'):
                b = rig.pose.bones[name]
                print('BONE', name, 'quat', list(b.rotation_quaternion), 'loc', list(b.matrix.translation), 'scale', list(b.matrix.to_scale()))
    print('DONE', code, flush=True)
