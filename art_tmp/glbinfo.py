import json,struct,glob,os
def info(p):
    d=open(p,'rb').read()
    n=struct.unpack('<I',d[12:16])[0]
    j=json.loads(d[20:20+n])
    tris=0
    for m in j.get('meshes',[]):
        for pr in m.get('primitives',[]):
            if 'indices' in pr: tris += j['accessors'][pr['indices']]['count']//3
            else: tris += j['accessors'][pr['attributes']['POSITION']]['count']//3
    return tris, len(j.get('meshes',[])), len(j.get('images',[])), len(j.get('skins',[])), len(j.get('animations',[])), len(j.get('textures',[]))
for p in sorted(glob.glob('001/art/models/*.glb')):
    t,me,im,sk,an,tx=info(p)
    print(f"{os.path.basename(p):28s} tris={t:7d} mesh={me} img={im} skin={sk} anim={an} tex={tx} {os.path.getsize(p)//1024}KB")