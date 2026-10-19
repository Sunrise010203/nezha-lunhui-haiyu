import bpy, collections
from mathutils import Vector
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=r"E:/godot_game_by_fable/001/art/models/nezha_opt.glb")
mem=bpy.data.objects["nezha_body"]; me=mem.data
ca=me.color_attributes[0]
PAL={(1.0,1.0,1.0):"white",(0.847,0.617,0.120):"gold",(0.701,0.100,0.070):"red",(0.050,0.040,0.050):"black",
     (0.552,0.060,0.050):"dred",(0.922,0.723,0.597):"skin",(0.922,0.888,0.839):"pale",(0.150,0.060,0.050):"leath"}
def near(c):
    b=None;bd=9
    for k,v in PAL.items():
        d=sum((c[i]-k[i])**2 for i in range(3))
        if d<bd: bd=d;b=v
    return b
# vertex color (take first loop per vert)
vcol={}
for li,l in enumerate(me.loops):
    if l.vertex_index not in vcol: vcol[l.vertex_index]=near(tuple(ca.data[li].color)[:3])
# union-find over edges
par=list(range(len(me.vertices)))
def f(i):
    while par[i]!=i: par[i]=par[par[i]]; i=par[i]
    return i
for e in me.edges:
    a,b=f(e.vertices[0]),f(e.vertices[1])
    if a!=b: par[a]=b
isl=collections.defaultdict(list)
for v in me.vertices: isl[f(v.index)].append(v.index)
print("islands:", len(isl))
rows=[]
for k,vs in isl.items():
    pts=[me.vertices[i].co for i in vs]
    xs=[p.x for p in pts]; ys=[p.y for p in pts]; zs=[p.z for p in pts]
    cols=collections.Counter(vcol.get(i,"?") for i in vs)
    rows.append((len(vs),min(xs),max(xs),min(ys),max(ys),min(zs),max(zs),cols.most_common(2)))
rows.sort(key=lambda r:-r[0])
for i,(n,x0,x1,y0,y1,z0,z1,c) in enumerate(rows[:22]):
    print(f"[{i:2d}] v={n:5d} x[{x0:+.2f},{x1:+.2f}] y[{y0:+.2f},{y1:+.2f}] z[{z0:+.2f},{z1:+.2f}] size=({x1-x0:.2f},{y1-y0:.2f},{z1-z0:.2f}) {c}")
