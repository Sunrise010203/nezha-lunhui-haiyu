"""Author encounter-specific in-place clips and inspect evaluated skin, not rig only."""
import json
import math
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Matrix, Quaternion, Vector
from bpy_extras.object_utils import world_to_camera_view

ROOT=Path('E:/godot_game_by_fable')
SOURCE=ROOT/'art_source/bosses'
OUT=ROOT/'_review/bosses_arp'
sys.path.insert(0,str(ROOT/'tools/blender'))
from build_boss_arp import KINDS

COMMON={'Idle':61,'Move':31,'Windup':25,'Attack':13,'Recover':22,'Hit':10,'Summon':34,'Phase':37,'Die':46}
EXTRA={'01':{'DiveWindup':22,'DiveAttack':13,'Sweep':31},'02':{'SlamWindup':25,'SlamAttack':8,'SlamRecover':25,'Charge':25},
       '03':{},'04':{'Pulse':28},'05':{'Bite':18,'Inhale':61,'Expose':61,'CoreOpen':31},'06':{}}


def run(code):
    kind=KINDS[code]
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE/(code+'_'+kind+'_arp.blend')))
    scene=bpy.context.scene
    rig=bpy.data.objects['Boss_'+code+'_ARP_Rig']
    meshes=[o for o in scene.objects if o.type=='MESH' and any(m.type=='ARMATURE' and m.object==rig for m in o.modifiers)]
    body=bpy.data.objects['Boss_'+code+'_Body']
    data=json.loads((OUT/(code+'_rig.json')).read_text())
    controls=list(data['joints']) if code!='02' else ['c_root_master.x','c_spine_01.x','c_spine_02.x','c_neck.x','c_head.x']
    if code=='02':
        controls.append('cc_weapon')
        for side in ['l','r']:
            controls += ['c_'+b+'.'+side for b in ['shoulder','arm_fk','forearm_fk','hand_fk','thigh_fk','leg_fk','foot_fk','toes_fk']]
    rig.animation_data_create();rig.animation_data.action=None
    for track in list(rig.animation_data.nla_tracks):rig.animation_data.nla_tracks.remove(track)
    for a in list(bpy.data.actions):
        if a.name.startswith('Boss_'+code+'_'):bpy.data.actions.remove(a)

    def reset():
        for b in rig.pose.bones:b.matrix_basis=Matrix.Identity(4)
        if code=='02':
            for side in ['l','r']:
                for limb in ['hand','foot']:rig.pose.bones['c_'+limb+'_ik.'+side]['ik_fk_switch']=1.0
        rig.update_tag();bpy.context.view_layer.update()

    def rotate(name,angle,axis=(1,0,0)):
        b=rig.pose.bones[name];b.rotation_mode='QUATERNION'
        b.rotation_quaternion=Quaternion(b.bone.matrix_local.to_3x3().inverted()@Vector(axis),angle)

    def move(name,delta):
        b=rig.pose.bones[name];b.location=b.bone.matrix_local.to_3x3().inverted()@Vector(delta)

    def positions(obj):
        evaluated=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=evaluated.to_mesh()
        array=np.empty(len(mesh.vertices)*3,dtype=np.float32);mesh.vertices.foreach_get('co',array)
        evaluated.to_mesh_clear()
        return array.reshape(-1,3)

    rest=np.array([list(v.co) for v in body.data.vertices])
    edges=np.array([list(e.vertices) for e in body.data.edges])
    lengths=np.linalg.norm(rest[edges[:,0]]-rest[edges[:,1]],axis=1)
    valid=lengths>.0015
    scene.render.fps=30;scene.render.fps_base=1
    clips={**COMMON,**EXTRA[code],'QA_Raise':2,'QA_Bend':2,'QA_Turn':2}
    report=dict(code=code,kind=kind,clips={},joint_screen={},rig_method=data['arp_preset'])
    for label,count in clips.items():
        rig.animation_data.action=None;reset()
        action=bpy.data.actions.new('Boss_'+code+'_'+label);action.use_fake_user=True
        rig.animation_data.action=action
        metrics=[]
        for frame in range(1,count+1):
            scene.frame_set(frame);reset()
            t=(frame-1)/max(1,count-1);wave=math.sin(t*math.tau)
            wind=t if label in ['Windup','SlamWindup','DiveWindup'] else 0
            strike=math.sin(t*math.pi/2) if label in ['Attack','SlamAttack','DiveAttack','Bite','Pulse'] else 1-t if label=='Recover' else 0
            hit=math.sin(t*math.pi) if label=='Hit' else 0
            summon=math.sin(t*math.pi) if label in ['Summon','Phase'] else 0
            die=t if label=='Die' else 0
            if code=='02':
                slamwind=(t/.72 if t<.72 else (1-t)/.28) if label=='SlamWindup' else 0
                impact=max(0,(t-.72)/.28) if label=='SlamWindup' else 1 if label=='SlamAttack' else 1-t if label=='SlamRecover' else 0
                if label in ['SlamWindup','SlamAttack','SlamRecover']:
                    wind=slamwind;strike=impact
                root='c_root_master.x'
                move(root,(0,0,.003*abs(wave) if label in ['Move','Charge'] else -.01*die))
                rotate('c_spine_01.x',wind*-.04+strike*.08+hit*-.06+die*.18)
                rotate('c_head.x',wave*.012+wind*-.03+strike*.035)
                rotate('cc_weapon',3.05*impact)
                for side,sign in [('l',1),('r',-1)]:
                    arm=wave*.07*sign if label in ['Move','Charge'] else -.04*wave
                    leg=wave*.18*sign if label in ['Move','Charge'] else 0
                    knee=max(0,-leg)*1.1
                    if side=='r':arm=-1.55*slamwind-.36*max(strike,impact)-.18*summon
                    else:arm+=-.45*slamwind-.35*summon
                    rotate('c_arm_fk.'+side,arm)
                    rotate('c_forearm_fk.'+side,-.55*slamwind if side=='r' else -.08*summon)
                    if side=='r':rotate('c_hand_fk.r',.8*slamwind)
                    rotate('c_thigh_fk.'+side,leg)
                    rotate('c_leg_fk.'+side,knee)
                    rotate('c_foot_fk.'+side,-leg-knee)
                if label=='QA_Raise':
                    for side in ['l','r']:rotate('c_arm_fk.'+side,-1.22*t);rotate('c_forearm_fk.'+side,-.32*t)
                elif label=='QA_Bend':
                    move(root,(0,0,-.03*t))
                    for side in ['l','r']:
                        rotate('c_thigh_fk.'+side,-.4*t);rotate('c_leg_fk.'+side,.8*t);rotate('c_foot_fk.'+side,-.4*t)
                elif label=='QA_Turn':rotate('c_spine_01.x',.35*t,(0,0,1))
            else:
                tilt=wind*-.025+strike*.035+hit*.045+die*.22
                rotate('cc_body',tilt)
                if label=='QA_Turn':rotate('cc_body',math.pi/3*t,(0,0,1))
                if code=='01':
                    for i,chain in enumerate(data['chains']):
                        for j,n in enumerate(chain):
                            angle=math.sin(t*math.tau+i*.7-j*.5)*(.025 if label=='Idle' else .045)+wind*-.045+strike*.05
                            if label in ['QA_Raise','QA_Bend']:angle=t*(.12 if label=='QA_Raise' else .16)
                            rotate(n,angle,(1,0,0) if i%2 else (0,1,0))
                elif code in ['03','04']:
                    # Closed shells are rigid; do not stretch seams to fake an opening.
                    lens='cc_lens' if code=='03' else 'cc_eye'
                    rotate(lens,wave*.012+wind*.012-strike*.012,(0,0,1))
                    if label in ['QA_Raise','QA_Bend']:rotate(lens,.025*t,(1,0,0))
                elif code=='05':
                    rotate('cc_head',wave*.006-wind*.04+strike*.045+hit*.025)
                    rotate('cc_jaw',.035*strike+.022*wind+(.035 if label=='Inhale' else 0))
                    for j in range(4):
                        rotate(f'cc_tail_{j:02d}',math.sin(t*math.tau-j*.6)*(.06 if label in ['Move','Sweep'] else .025)+wind*.025-strike*.025,(0,0,1))
                    for side,sign in [('l',1),('r',-1)]:rotate('cc_fin.'+side,wave*.035*sign,(0,1,0))
                    if label=='CoreOpen':
                        rotate('cc_chest',.12,(1,0,0));move('cc_chest',(0,-.025,0))
                    if label=='QA_Raise':
                        for side,sign in [('l',1),('r',-1)]:rotate('cc_fin.'+side,.12*t*sign,(0,1,0))
                    if label=='QA_Bend':
                        for j in range(4):rotate(f'cc_tail_{j:02d}',.12*t,(0,0,1))
            for name in controls:
                b=rig.pose.bones[name];b.rotation_mode='QUATERNION'
                b.keyframe_insert('rotation_quaternion',frame=frame,group=name)
                b.keyframe_insert('location',frame=frame,group=name)
            rig.update_tag();bpy.context.view_layer.update()
            p=positions(body)
            ratio=np.linalg.norm(p[edges[valid,0]]-p[edges[valid,1]],axis=1)/lengths[valid]
            assert np.isfinite(p).all()
            metrics.append(dict(frame=frame,p99_stretch=float(np.quantile(ratio,.99)),max_stretch=float(ratio.max()),
                                p01_compression=float(np.quantile(ratio,.01))))
        report['clips'][label]=dict(frames=count,seconds=(count-1)/30,max_p99_stretch=max(m['p99_stretch'] for m in metrics),
                                   max_edge_stretch=max(m['max_stretch'] for m in metrics),metrics=metrics)

    camera_data=bpy.data.cameras.new('PoseReviewCamera');camera_data.type='ORTHO'
    camera=bpy.data.objects.new('PoseReviewCamera',camera_data);scene.collection.objects.link(camera);scene.camera=camera
    extent=max(np.ptp(rest,axis=0));camera_data.ortho_scale=max(1.6 if code=='02' else 1.35,extent*1.3)
    scene.render.engine='BLENDER_WORKBENCH';scene.display.shading.color_type='TEXTURE'
    scene.display.shading.show_cavity=True;scene.world.color=(.12,.12,.12)
    scene.render.resolution_x=640;scene.render.resolution_y=720;scene.render.resolution_percentage=100
    for label in ['Rest','QA_Raise','QA_Bend','QA_Turn','Windup','Attack']+list(EXTRA[code]):
        rig.animation_data.action=None;reset()
        if label!='Rest':
            a=bpy.data.actions['Boss_'+code+'_'+label];rig.animation_data.action=a;rig.animation_data.action_slot=a.slots[0]
            scene.frame_set(clips[label] if label.startswith('QA_') or label.endswith('Windup') else max(1,clips[label]//2))
        rig.update_tag();bpy.context.view_layer.update()
        for view,direction in [('front',(.15,-1,.06)),('side',(1,0,.05))]:
            target=Vector((0,0,.52));camera.location=target+Vector(direction).normalized()*5
            camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
            scene.render.filepath=str(OUT/(code+'_'+label+'_'+view+'.png'))
            bpy.ops.render.render(write_still=True)
            if label=='Rest':
                report['joint_screen'][view]=[]
                for n,item in data['joints'].items():
                    if n.startswith(('thumb','index','middle','pinky','ring')) or any(s in n for s in ['heel','bank']):continue
                    coords=[world_to_camera_view(scene,camera,Vector(item[k])) for k in ['head','tail']]
                    report['joint_screen'][view].append(dict(name=n,points=[[v.x*640,(1-v.y)*720] for v in coords]))
    rig.animation_data.action=None;reset()
    for label in {**COMMON,**EXTRA[code]}:
        track=rig.animation_data.nla_tracks.new();track.name=label
        a=bpy.data.actions['Boss_'+code+'_'+label]
        strip=track.strips.new(label,1,a);strip.action_slot=a.slots[0];strip.extrapolation='NOTHING';track.mute=True
    scene.frame_start=1;scene.frame_end=61;scene.frame_set(1)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in meshes:obj.select_set(True)
    rig.select_set(True);bpy.context.view_layer.objects.active=rig
    originals=[];small_images={}
    for obj in meshes:
        for mat in obj.data.materials:
            for node in mat.node_tree.nodes:
                if node.type=='TEX_IMAGE' and node.image and max(node.image.size)>2048:
                    original=node.image
                    if original.name not in small_images:
                        small=original.copy();small.name=code+'_Game_'+original.name
                        scale=2048/max(original.size);small.scale(round(original.size[0]*scale),round(original.size[1]*scale))
                        small_images[original.name]=small
                    originals.append((node,original));node.image=small_images[original.name]
    game=ROOT/'001/art/models/bosses_arp';game.mkdir(exist_ok=True)
    assert bpy.ops.export_scene.gltf(filepath=str(game/(code+'_'+kind+'.glb')),export_format='GLB',use_selection=True,
        export_skins=True,export_def_bones=True,export_yup=True,export_animations=True,export_animation_mode='NLA_TRACKS',
        export_merge_animation='NLA_TRACK',export_force_sampling=True,export_frame_range=False,export_all_influences=False,
        export_materials='EXPORT',export_image_format='AUTO',export_extras=False,export_cameras=False,export_lights=False)=={'FINISHED'}
    for node,original in originals:node.image=original
    for image in small_images.values():bpy.data.images.remove(image)
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/(code+'_'+kind+'_arp.blend')),compress=True)
    (OUT/(code+'_motion.json')).write_text(json.dumps(report,indent=2),encoding='utf-8')
    print('BOSS_EXPORTED',code,{n:round(d['max_p99_stretch'],3) for n,d in report['clips'].items()},flush=True)


if __name__=='__main__':
    for code in (sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else KINDS):run(code)
