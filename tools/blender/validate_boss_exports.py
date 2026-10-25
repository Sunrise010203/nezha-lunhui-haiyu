"""Round-trip GLB skins and compare evaluated world surfaces to ARP source poses."""
import hashlib
import json
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils.kdtree import KDTree

ROOT=Path('E:/godot_game_by_fable')
sys.path.insert(0,str(ROOT/'tools/blender'))
from build_boss_arp import KINDS
OUT=ROOT/'_review/bosses_arp'
SOURCE=ROOT/'art_source/bosses'
report={}


def points(objects):
    result=[]
    for obj in objects:
        ev=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());m=ev.to_mesh()
        result.extend([tuple(ev.matrix_world@v.co) for v in m.vertices]);ev.to_mesh_clear()
    return result


for code,kind in KINDS.items():
    path=SOURCE/(code+'_'+kind+'_arp.blend')
    bpy.ops.wm.open_mainfile(filepath=str(path))
    rig=bpy.data.objects['Boss_'+code+'_ARP_Rig']
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH' and any(m.type=='ARMATURE' and m.object==rig for m in o.modifiers)]
    labels=['Idle','Attack','Move']+(['SlamWindup','SlamAttack'] if code=='02' else ['CoreOpen'] if code=='05' else [])
    source_poses={}
    for label in labels:
        a=bpy.data.actions['Boss_'+code+'_'+label];rig.animation_data.action=a;rig.animation_data.action_slot=a.slots[0]
        bpy.context.scene.frame_set(round(a.frame_range[1]*.6));rig.update_tag();bpy.context.view_layer.update()
        source_poses[label]=points(meshes)
    ground_contact=None
    if code=='02':
        a=bpy.data.actions['Boss_02_SlamAttack'];rig.animation_data.action=a;rig.animation_data.action_slot=a.slots[0]
        bpy.context.scene.frame_set(4);rig.update_tag();bpy.context.view_layer.update()
        ground_contact=min(p[2] for p in points([bpy.data.objects['Warden_Mace']]))*3.9
        assert -.035<ground_contact<.15, ('Hammer ground contact out of tolerance',ground_contact)
        assert rig.data.bones['cc_weapon'].parent.name=='hand.r'
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    before=set(bpy.data.objects)
    glb=ROOT/'001/art/models/bosses_arp'/(code+'_'+kind+'.glb')
    bpy.ops.import_scene.gltf(filepath=str(glb))
    imported=[o for o in bpy.data.objects if o not in before]
    irig=next(o for o in imported if o.type=='ARMATURE')
    # ARP's enabled addon can create controller-display meshes during glTF import.
    # Compare actual imported skin geometry, not UI custom-shape objects.
    custom_shapes={b.custom_shape for b in irig.pose.bones if b.custom_shape}
    print('IMPORTED_MESHES',code,[(o.name,len(o.data.vertices),o in custom_shapes,[(m.type,m.object.name if m.type=='ARMATURE' and m.object else None) for m in o.modifiers]) for o in imported if o.type=='MESH'],flush=True)
    imeshes=[o for o in imported if o.type=='MESH' and o not in custom_shapes]
    tracks={track.name:track for track in irig.animation_data.nla_tracks}
    for track in tracks.values():track.mute=True
    samples={}
    for label in labels:
        strip=tracks[label].strips[0]
        a=strip.action;irig.animation_data.action=a;irig.animation_data.action_slot=strip.action_slot
        bpy.context.scene.frame_set(round(a.frame_range[1]*.6));irig.update_tag();bpy.context.view_layer.update()
        tree=KDTree(len(source_poses[label]))
        for i,p in enumerate(source_poses[label]):tree.insert(p,i)
        tree.balance()
        distances=np.array([tree.find(p)[2] for p in points(imeshes)])
        samples[label]=dict(max_surface_distance=float(distances.max()),p99_distance=float(np.quantile(distances,.99)))
        if distances.max()>=.002:
            offset=0
            for obj in imeshes:
                verts=points([obj]);bad=[i for i in range(len(verts)) if distances[offset+i]>=.002]
                print('ROUNDTRIP_OUTLIERS',obj.name,len(verts),'bad',len(bad),'examples',[(i,verts[i],tree.find(verts[i])) for i in bad[:12]],flush=True)
                offset+=len(verts)
        assert distances.max()<.002, (code,label,samples[label])
    rig_report=json.loads((OUT/(code+'_rig.json')).read_text())
    motion=json.loads((OUT/(code+'_motion.json')).read_text())
    worst=max(d['max_p99_stretch'] for d in motion['clips'].values())
    assert worst<1.35,(code,worst)
    original=SOURCE/'source'/(code+'.glb')
    assert hashlib.sha256(original.read_bytes()).hexdigest()==hashlib.sha256((Path('C:/Users/Sunrise/Downloads')/original.name).read_bytes()).hexdigest()
    report[code]=dict(kind=kind,arp_bind_result=rig_report['arp_bind_result'],unweighted=rig_report['weights']['unweighted'],
        worst_p99_edge_stretch_including_qa=worst,roundtrip=samples,ground_contact_m=ground_contact,
        source_original_hash_preserved=True,source_blend=str(path),game_glb=str(glb),
        game_sha256=hashlib.sha256(glb.read_bytes()).hexdigest(),game_clips=list(tracks),game_bones=len(irig.data.bones))
    print('BOSS_ROUNDTRIP_PASS',code,samples,flush=True)
(OUT/'export_validation.json').write_text(json.dumps(dict(passed=True,assets=report),indent=2),encoding='utf-8')
print('BOSS_EXPORT_VALIDATION_PASS',flush=True)
