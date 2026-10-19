import bpy, collections
from mathutils import Vector
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=r"E:/godot_game_by_fable/001/art/models/nezha_opt.glb")
mem = bpy.data.objects["nezha_body"]; rig = bpy.data.objects["rig"]
print("rig.matrix_world:", [round(v,3) for r in rig.matrix_world for v in r])
print("mem.matrix_world:", [round(v,3) for r in mem.matrix_world for v in r])
W = mem.matrix_world
print("=== BONES world (head -> tail) ===")
for b in rig.data.bones:
    h = rig.matrix_world @ b.head_local; t = rig.matrix_world @ b.tail_local
    print(f"{b.name:12s} ({h.x:+.3f},{h.y:+.3f},{h.z:+.3f}) -> ({t.x:+.3f},{t.y:+.3f},{t.z:+.3f}) len={b.length:.3f}")
me = mem.data; ca = me.color_attributes[0]
PAL = {(1.0,1.0,1.0):"white",(0.847,0.617,0.120):"gold",(0.701,0.100,0.070):"red",(0.050,0.040,0.050):"black",
       (0.552,0.060,0.050):"dred",(0.922,0.723,0.597):"skin",(0.922,0.888,0.839):"pale",(0.150,0.060,0.050):"leath"}
def near(c):
    best=None;bd=9
    for k,v in PAL.items():
        d=sum((c[i]-k[i])**2 for i in range(3))
        if d<bd: bd=d;best=v
    return best
buckets=collections.defaultdict(list)
for li in range(len(me.loops)):
    vi=me.loops[li].vertex_index; col=ca.data[li].color
    buckets[near((col[0],col[1],col[2]))].append(W @ me.vertices[vi].co)
print("=== REGIONS world ===")
for k,v in sorted(buckets.items(), key=lambda kv:-len(kv[1])):
    xs=[p.x for p in v]; ys=[p.y for p in v]; zs=[p.z for p in v]
    print(f"{k:6s} n={len(v):5d} x[{min(xs):+.3f},{max(xs):+.3f}] y[{min(ys):+.3f},{max(ys):+.3f}] z[{min(zs):+.3f},{max(zs):+.3f}]")
allp=[W @ v.co for v in me.vertices]
print("WORLD bbox min", tuple(round(min(p[i] for p in allp),3) for i in range(3)), "max", tuple(round(max(p[i] for p in allp),3) for i in range(3)))
