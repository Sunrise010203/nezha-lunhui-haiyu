"""Fit licensed ARP human/free rigs, bind, then correct anatomical weights."""
import json
import math
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.kdtree import KDTree

ROOT = Path('E:/godot_game_by_fable')
sys.path.insert(0, str(ROOT / 'tools/blender'))
from build_enemy_arp import components
from enemy_arp_anatomy import segment_distances, slice_centers

OUT = ROOT / '_review/bosses_arp'
SOURCE = ROOT / 'art_source/bosses'
KINDS = {'01': 'maw', '02': 'warden', '03': 'seal_core', '04': 'giant_eye', '05': 'chiwen', '06': 'warden_mace'}


def smooth(x):
    x = np.clip(x, 0, 1)
    return x * x * (3 - 2 * x)


def fit_human(rig):
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode='EDIT')
    bones = rig.data.edit_bones
    rig.data.use_mirror_x = False
    original = {b.name: (b.head.copy(), b.tail.copy()) for b in bones if 'ref' in b.name}
    targets = {
        'root_ref.x': ((0, .015, .46), (0, .015, .54)),
        'spine_01_ref.x': ((0, .015, .54), (0, .015, .65)),
        'spine_02_ref.x': ((0, .015, .65), (0, .015, .79)),
        'neck_ref.x': ((0, .015, .79), (0, .005, .845)),
        'head_ref.x': ((0, .005, .845), (0, .005, .95)),
    }
    for side, sign in [('l', 1), ('r', -1)]:
        def p(x, y, z):
            return (sign * x, y, z)
        shoulder, elbow = p(.211, .015, .771), p(.273, .005, .603)
        wrist, hand = p(.301, -.045, .469), p(.31, -.048, .365)
        hip, knee, ankle = p(.122, .018, .458), p(.155, .005, .254), p(.171, .018, .074)
        ball = p(.171, -.074, .033)
        targets.update({'shoulder_ref.' + side: (p(.055, .015, .79), shoulder),
            'arm_ref.' + side: (shoulder, elbow), 'forearm_ref.' + side: (elbow, wrist),
            'hand_ref.' + side: (wrist, hand), 'thigh_ref.' + side: (hip, knee),
            'leg_ref.' + side: (knee, ankle), 'foot_ref.' + side: (ankle, ball),
            'toes_ref.' + side: (ball, p(.171, -.12, .026)),
            'foot_heel_ref.' + side: (p(.171, .075, .01), p(.171, .06, .01)),
            'foot_bank_01_ref.' + side: (p(.221, .075, .01), p(.221, .06, .01)),
            'foot_bank_02_ref.' + side: (p(.121, .075, .01), p(.121, .06, .01))})
        old_head, old_tail = original['hand_ref.' + side]
        rot = (old_tail - old_head).rotation_difference(Vector(hand) - Vector(wrist))
        for name, (head, tail) in original.items():
            if name.endswith('.' + side) and name.startswith(('thumb', 'index', 'middle', 'ring', 'pinky')):
                targets[name] = (Vector(wrist) + rot @ ((head - old_head) * .36), Vector(wrist) + rot @ ((tail - old_head) * .36))
    for name, (head, tail) in targets.items():
        bones[name].head, bones[name].tail = head, tail
    bpy.ops.object.mode_set(mode='OBJECT')
    assert bpy.ops.arp.match_to_rig() == {'FINISHED'}
    bpy.ops.object.mode_set(mode='OBJECT')
    return {n: dict(head=list(h), tail=list(t)) for n, (h, t) in targets.items()}


def custom_layout(code, points):
    bones, chains = {}, []
    def bone(name, head, tail, parent='cc_body'):
        bones[name] = dict(head=list(head), tail=list(tail), parent=parent)
        return name
    center = (0, 0, .60) if code == '01' else (0, -.05, .43) if code == '05' else (0, 0, .5)
    bone('cc_body', center, np.array(center) + (0, 0, .12), 'c_traj')
    if code == '01':
        stems = slice_centers(points, .30, .036, .008)
        assert len(stems) == 8, 'Review branch count, never silently merge limbs'
        for i, stem in enumerate(stems):
            rear = stem[1] > .2
            joints = [(float(stem[0] * .84), float(stem[1] * .82), .37)]
            last = stem
            for z in [.30, .24, .18] + ([.15] if rear else [.10, .035]):
                section = slice_centers(points, z, .036, .008)
                if section:
                    closest = min(section, key=lambda v: np.linalg.norm(v[:2] - last[:2]))
                    if np.linalg.norm(closest[:2] - last[:2]) < .19:
                        last = closest
                joints.append((float(last[0]), float(last[1]), z))
            chain = []
            for j in range(len(joints) - 1):
                chain.append(bone(f'cc_tentacle_{i:02d}_{j:02d}', joints[j], joints[j + 1], chain[-1] if chain else 'cc_body'))
            chains.append(chain)
    elif code in ('03', '04'):
        bone('cc_lens' if code == '03' else 'cc_eye', (0, -.18, .43 if code == '03' else .5), (0, -.54, .43 if code == '03' else .5))
        for name, head, tail in [('upper', (0, .20, .77), (0, -.25, .86)), ('lower', (0, .20, .18), (0, -.25, .12)),
                                 ('left', (.32, .20, .48), (.48, -.20, .48)), ('right', (-.32, .20, .48), (-.48, -.20, .48))]:
            bone('cc_shell_' + name, head, tail)
    elif code == '05':
        bone('cc_head', (0, -.30, .47), (0, -.66, .53))
        bone('cc_jaw', (0, -.55, .47), (0, -.72, .435), 'cc_head')
        bone('cc_chest', (0, -.39, .38), (0, -.44, .15), 'cc_head')
        joints = [(0, .05, .43), (0, .28, .43), (0, .49, .43), (0, .66, .43), (0, .78, .43)]
        chain = []
        for j in range(4):
            chain.append(bone(f'cc_tail_{j:02d}', joints[j], joints[j+1], chain[-1] if chain else 'cc_body'))
        chains.append(chain)
        for sign, side in [(1,'l'),(-1,'r')]:
            bone('cc_fin.' + side, (sign*.20,-.24,.24), (sign*.51,-.11,.10))
    return bones, chains


def weights(code, body, rig, points, groups, chains):
    names = [b.name for b in rig.data.bones if b.use_deform]
    idx = {name: i for i, name in enumerate(names)}
    w = np.zeros((len(points), len(names)), dtype=np.float32)
    base = 'root.x' if code == '02' else 'cc_body'
    w[:, idx[base]] = 1
    x, y, z = points.T
    if code == '02':
        # Armour remains rigid away from actual shoulder/elbow/hip/knee bands.
        torso = smooth((z - .51) / .12)
        w[:, idx[base]] = 1 - torso
        w[:, idx['spine_02.x']] = torso
        head = smooth((z - .81) / .045)
        w *= (1 - head[:, None]); w[:, idx['head.x']] += head
        for group in groups:
            part = points[group]
            c, lo, hi = part.mean(0), part.min(0), part.max(0)
            side = 'l' if c[0] > 0 else 'r'
            if abs(c[0]) > .22 and hi[2] < .51 and lo[2] > .30:
                w[group] = 0; w[group, idx['hand.' + side]] = 1
            elif abs(c[0]) > .21 and lo[2] > .43:
                a = smooth((part[:,2] - .578) / .052)
                w[group] = 0
                w[group, idx['arm_stretch.' + side]] = a
                w[group, idx['forearm_stretch.' + side]] = 1-a
            elif hi[2] < .58 and lo[2] < .10:
                w[group] = 0
                pg = points[group]
                root = smooth((pg[:,2] - .397) / .075)
                leg = smooth((pg[:,2] - .224) / .055)
                foot = smooth((.105 - pg[:,2]) / .045)
                w[group,idx[base]] = root
                for s, sign in [('l',1),('r',-1)]:
                    amount = smooth((pg[:,0]*sign + .025)/.05)
                    w[group,idx['thigh_stretch.'+s]] = (1-root)*leg*amount
                    w[group,idx['leg_stretch.'+s]] = (1-root)*(1-leg)*(1-foot)*amount
                    w[group,idx['foot.'+s]] = (1-root)*(1-leg)*foot*amount
        # Tiny separated rivets copy nearest major surface, not nearby other limbs.
        major = np.concatenate([g for g in groups if len(g)>1000])
        tree=KDTree(len(major))
        for vi in major: tree.insert(points[vi],int(vi))
        tree.balance()
        for group in groups:
            if len(group)<300:
                center=points[group].mean(0)
                w[group]=0
                if abs(center[0])>.17 and center[2]>.68:
                    side='l' if center[0]>0 else 'r'
                    w[group,idx['arm_stretch.'+side]]=1
                else:
                    nearest=tree.find(center)[1]
                    w[group,int(w[nearest].argmax())]=1
    elif code == '01':
        distances = np.array([[segment_distances(points,rig.data.bones[n].head_local,rig.data.bones[n].tail_local)[0] for n in c] for c in chains], dtype=object)
        mins=np.stack([np.stack(ds).min(0) for ds in distances])
        closest=mins.argmin(0)
        strength=smooth((.395-z)/.085)
        w[:,idx[base]]=1-strength
        for ci, chain in enumerate(chains):
            ids=np.flatnonzero((closest==ci)&(strength>0))
            for vi in ids:
                ds=[segment_distances(points[vi:vi+1],rig.data.bones[n].head_local,rig.data.bones[n].tail_local) for n in chain]
                j=min(range(len(ds)),key=lambda j:ds[j][0][0])
                pos=float(np.clip(j+ds[j][1][0]-.5,0,len(chain)-1))
                start=int(pos)
                w[vi,idx[chain[start]]]+=strength[vi]*(1-(pos-start))
                w[vi,idx[chain[min(start+1,len(chain)-1)]]]+=strength[vi]*(pos-start)
    elif code in ('03','04'):
        for g in groups:
            c=points[g].mean(0); lo=points[g].min(0); hi=points[g].max(0)
            name=base
            if code=='03' and c[1]<-.43 and abs(c[0])<.065 and hi[2]<.60:
                name='cc_lens'
            elif code=='04' and c[1]<-.30 and abs(c[0])<.06 and hi[2]<.84 and lo[2]>.12:
                name='cc_eye'
            elif len(g)>500:
                name='cc_shell_'+('upper' if c[2]>.67 else 'lower' if c[2]<.23 else 'left' if c[0]>.18 else 'right' if c[0]<-.18 else 'upper')
            w[g]=0;w[g,idx[name]]=1
    elif code=='05':
        head=smooth((-.20-y)/.22)
        w[:,idx[base]]=1-head;w[:,idx['cc_head']]=head
        strength=smooth((y-.02)/.13)
        w*=1-strength[:,None]
        pos=np.clip((y-.05)/.19-.5,0,3)
        for j in range(4): w[:,idx[f'cc_tail_{j:02d}']]+=strength*np.maximum(0,1-np.abs(pos-j))
        fin=smooth((np.abs(x)-.245)/.10)*smooth((.34-z)/.13)
        fin*=smooth((y+.46)/.1)*(1-smooth((y-.05)/.15))
        w*=1-fin[:,None]
        w[:,idx['cc_fin.l']]+=fin*(x>0);w[:,idx['cc_fin.r']]+=fin*(x<=0)
        for g in groups:
            c=points[g].mean(0);lo=points[g].min(0);hi=points[g].max(0)
            if 500<len(g)<1000 and -.49<c[1]<-.35 and c[2]<.32:
                w[g]=0;w[g,idx['cc_chest']]=1
            elif c[1]<-.50 and .4<c[2]<.49 and hi[2]<.52:
                w[g]=0;w[g,idx['cc_jaw']]=1
    if code in ('01','02','05'):
        edges=np.array([list(e.vertices) for e in body.data.edges])
        dst=np.r_[edges[:,0],edges[:,1]];src=np.r_[edges[:,1],edges[:,0]]
        degree=np.maximum(np.bincount(dst,minlength=len(points)),1)
        active=np.flatnonzero(w.max(0)>0)
        for _ in range(14 if code!='02' else 5):
            for bi in active:
                avg=np.bincount(dst,weights=w[src,bi],minlength=len(points))/degree
                w[:,bi]=w[:,bi]*.55+avg*.45
    w/=np.maximum(w.sum(1,keepdims=True),1e-12)
    assert np.isfinite(w).all() and (w.sum(1)>.999).all()
    body.vertex_groups.clear()
    for name in names: body.vertex_groups.new(name=name)
    for vi in range(len(points)):
        order=np.argsort(w[vi])[-4:];order=order[w[vi,order]>1e-5]
        values=w[vi,order];values/=values.sum()
        for i,value in zip(order,values):body.vertex_groups[names[i]].add([vi],float(value),'REPLACE')
    return dict(unweighted=0,max_influences=4,used_groups=[names[i] for i in np.flatnonzero(w.max(0)>1e-5)])


def build(code):
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE/(code+'_canonical.blend')))
    scene=bpy.context.scene
    body=bpy.data.objects['Boss_'+code+'_Body']
    points=np.array([list(v.co) for v in body.data.vertices])
    groups=components(body)
    area=next(a for a in bpy.context.screen.areas if a.type=='VIEW_3D')
    region=next(r for r in area.regions if r.type=='WINDOW')
    with bpy.context.temp_override(area=area,region=region):
        bpy.ops.arp.append_arp(rig_preset='human' if code=='02' else 'free')
        rig=bpy.context.active_object
        rig.name='Boss_'+code+'_ARP_Rig';rig.show_in_front=True
        chains=[]
        if code=='02':
            layout=fit_human(rig)
            bpy.ops.object.mode_set(mode='EDIT')
            b=rig.data.edit_bones.new('cc_weapon')
            b.head=(-.315,-.075,.409);b.tail=(-.315,-.075,.609)
            b.parent=rig.data.edit_bones['hand.r'];b.use_deform=True
            bpy.ops.armature.select_all(action='DESELECT');b.select=True
            assert bpy.ops.arp.set_bone_tag(tag='cc')=={'FINISHED'}
            bpy.ops.object.mode_set(mode='OBJECT')
            layout['cc_weapon']=dict(head=[-.315,-.075,.409],tail=[-.315,-.075,.609],parent='hand.r')
        else:
            layout,chains=custom_layout(code,points)
            bpy.ops.object.mode_set(mode='EDIT')
            for name,data in layout.items():
                b=rig.data.edit_bones.new(name);b.head=data['head'];b.tail=data['tail']
                b.parent=rig.data.edit_bones[data['parent']];b.use_deform=True
            bpy.ops.armature.select_all(action='DESELECT')
            for name in layout:rig.data.edit_bones[name].select=True
            assert bpy.ops.arp.set_bone_tag(tag='cc')=={'FINISHED'}
            bpy.ops.object.mode_set(mode='OBJECT')
        bpy.ops.object.select_all(action='DESELECT')
        body.select_set(True);rig.select_set(True);bpy.context.view_layer.objects.active=rig
        scene.arp_bind_engine='HEAT_MAP';scene.arp_bind_split=False
        scene.arp_bind_scale_fix=True;scene.arp_optimize_highres=False
        result=bpy.ops.arp.bind_to_rig()
        bpy.ops.object.mode_set(mode='OBJECT')
        rig.data.pose_position='POSE'
        initial=sum(not any(g.weight>1e-5 for g in v.groups) for v in body.data.vertices)
        report=weights(code,body,rig,points,groups,chains)
    for mod in body.modifiers:
        if mod.type=='ARMATURE':mod.use_deform_preserve_volume=False
    assert any(m.type=='ARMATURE' and m.object==rig for m in body.modifiers)
    if code=='02':
        bpy.ops.wm.append(filepath=str(SOURCE/'06_canonical.blend'/'Object'/'Boss_06_Body'),directory=str(SOURCE/'06_canonical.blend'/'Object')+'/',filename='Boss_06_Body')
        mace=bpy.data.objects['Boss_06_Body'];mace.name='Warden_Mace'
        scale=3/3.9
        transform=Matrix.Translation(Vector((-.315,-.075,.409-scale*.43)))@Matrix.Scale(scale,4)
        mace.data.transform(transform);mace.matrix_world=Matrix.Identity(4)
        mace.vertex_groups.clear();g=mace.vertex_groups.new(name='cc_weapon');g.add(list(range(len(mace.data.vertices))),1,'REPLACE')
        modifier=mace.modifiers.new('ARP_Right_Hand_Rigid','ARMATURE');modifier.object=rig
        mace.parent=rig
    for image in bpy.data.images:
        if image.users and image.source=='FILE' and not image.packed_file:image.pack()
    (OUT/(code+'_rig.json')).write_text(json.dumps(dict(code=code,kind=KINDS[code],arp_preset='human' if code=='02' else 'free + cc custom chains',
        arp_bind_result=sorted(result),initial_unweighted=initial,weights=report,joints=layout,chains=chains,
        deform_bones=[b.name for b in rig.data.bones if b.use_deform]),indent=2),encoding='utf-8')
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/(code+'_'+KINDS[code]+'_arp.blend')),compress=True)
    print('BOSS_RIG_READY',code,report,flush=True)


if __name__=='__main__':
    for code in (sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else KINDS):build(code)
