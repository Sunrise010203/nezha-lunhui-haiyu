import json,struct
p=r"E:/godot_game_by_fable/art_tmp/nezha_v2.glb"
d=open(p,'rb').read()
n=struct.unpack('<I',d[12:16])[0]
j=json.loads(d[20:20+n])
print("nodes",len(j.get('nodes',[])),"meshes",len(j.get('meshes',[])),"skins",len(j.get('skins',[])),"mats",[m.get('name') for m in j.get('materials',[])])
for i,nd in enumerate(j['nodes']):
    print(i, nd.get('name'), {k:v for k,v in nd.items() if k in ('mesh','skin','rotation','translation','scale','children')})
for m in j['meshes']:
    for pi,pr in enumerate(m['primitives']):
        acc=j['accessors'][pr['attributes']['POSITION']]
        print("prim",pi,"count",acc['count'],"min",[round(x,3) for x in acc['min']],"max",[round(x,3) for x in acc['max']],"attrs",list(pr['attributes'].keys()),"mat",pr.get('material'))
print("size",len(d))