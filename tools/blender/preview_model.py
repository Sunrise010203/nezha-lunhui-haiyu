# -*- coding: utf-8 -*-
import bpy, sys, math
from mathutils import Vector, Matrix
argv = sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
SRC = argv[0] if argv else r"E:/godot_game_by_fable/art_tmp/nezha_v2.glb"
OUT = argv[1] if len(argv)>1 else r"E:/godot_game_by_fable/art_tmp/preview/v2"
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
rig=[o for o in bpy.data.objects if o.type=='ARMATURE'][0]
def bw(n):
    b=rig.data.bones[n]; return rig.matrix_world @ ((b.head_local+b.tail_local)*0.5)
up=Vector((0,-1,0))   # 游戏里 pitch=-90 把 -Y 立起来，预览沿用同一约定
print("headW", tuple(round(x,3) for x in bw("head")), "hipsW", tuple(round(x,3) for x in bw("hips")))
right=(bw("hand.R")-bw("hand.L"))
if right.length < 1e-6: right = Vector((1,0,0))
right=right.normalized()
right=(right-up*right.dot(up)).normalized()
back=up.cross(right).normalized()
M=Matrix((right, back, up)).to_4x4()
for o in list(bpy.data.objects):
    if o.parent is None:
        o.matrix_world = M @ o.matrix_world
bpy.context.view_layer.update()
meshes=[o for o in bpy.data.objects if o.type=='MESH']
pts=[]
for o in meshes:
    for v in o.data.vertices: pts.append(o.matrix_world @ v.co)
mn=Vector((min(p.x for p in pts),min(p.y for p in pts),min(p.z for p in pts)))
mx=Vector((max(p.x for p in pts),max(p.y for p in pts),max(p.z for p in pts)))
ctr=(mn+mx)*0.5; size=max(mx.z-mn.z, 0.1)
print("bbox", tuple(round(x,3) for x in (mx-mn)), "ctr", tuple(round(x,3) for x in ctr))
sc=bpy.context.scene
sc.render.engine='CYCLES'; sc.cycles.samples=20; sc.cycles.use_denoising=True
sc.cycles.device='CPU'; sc.render.resolution_x=420; sc.render.resolution_y=560
sc.view_settings.view_transform='Standard'
w=bpy.data.worlds.new("W"); sc.world=w; w.use_nodes=True
bg=w.node_tree.nodes["Background"]; bg.inputs[0].default_value=(0.055,0.065,0.085,1); bg.inputs[1].default_value=1.0
def light(loc,energy,size=2.5):
    d=bpy.data.lights.new("L",'AREA'); d.energy=energy; d.size=size
    o=bpy.data.objects.new("L",d); o.location=loc; sc.collection.objects.link(o)
    o.rotation_euler=(ctr-Vector(loc)).to_track_quat('-Z','Y').to_euler()
light((ctr.x+2.0, ctr.y-1.8, ctr.z+2.2), 700)
light((ctr.x-1.8, ctr.y-1.2, ctr.z+0.6), 250)
light((ctr.x+0.2, ctr.y+2.0, ctr.z+1.4), 420)
cam_d=bpy.data.cameras.new("C"); cam_d.lens=80
cam=bpy.data.objects.new("C",cam_d); sc.collection.objects.link(cam); sc.camera=cam
for name,ang in (("front",0.0),("q34",38.0),("side",90.0)):
    a=math.radians(ang)
    d=Vector((math.sin(a), -math.cos(a), 0.10))
    loc=ctr+d.normalized()*(size*2.65)
    cam.location=loc
    cam.rotation_euler=(ctr-loc).to_track_quat('-Z','Y').to_euler()
    sc.render.filepath=f"{OUT}_{name}.png"
    bpy.ops.render.render(write_still=True)
    print("saved", sc.render.filepath)
