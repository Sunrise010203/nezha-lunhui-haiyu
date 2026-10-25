import json
from pathlib import Path
import bpy
import numpy as np
ROOT=Path('E:/godot_game_by_fable')
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art_source/bosses/02_warden_arp.blend'))
rig=bpy.data.objects['Boss_02_ARP_Rig'];body=bpy.data.objects['Boss_02_Body']
a=bpy.data.actions['Boss_02_QA_Raise'];rig.animation_data.action=a;rig.animation_data.action_slot=a.slots[0]
bpy.context.scene.frame_set(2);rig.update_tag();bpy.context.view_layer.update()
e=body.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=e.to_mesh()
p=np.array([list(v.co) for v in mesh.vertices]);rest=np.array([list(v.co) for v in body.data.vertices])
edges=np.array([list(e.vertices) for e in body.data.edges]);lengths=np.linalg.norm(rest[edges[:,0]]-rest[edges[:,1]],axis=1)
ratio=np.linalg.norm(p[edges[:,0]]-p[edges[:,1]],axis=1)/np.maximum(lengths,1e-9)
ids=np.flatnonzero(lengths>.0015);order=ids[np.argsort(ratio[ids])[-20:]]
for i in order:
    print('EDGE',round(ratio[i],2),rest[edges[i]].round(3).tolist(), [[(body.vertex_groups[g.group].name,round(g.weight,2)) for g in body.data.vertices[v].groups] for v in edges[i]])
for obj in [body,bpy.data.objects['Warden_Mace']]:
    print('OBJ',obj.name, 'matrix',list(obj.matrix_world.translation))
e.to_mesh_clear()
