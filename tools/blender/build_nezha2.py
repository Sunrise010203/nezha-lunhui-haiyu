# -*- coding: utf-8 -*-
"""build_nezha2.py — 程序化重建哪吒本体（保留原 22 骨骼，权重手写，动画零改动）"""
import bpy, bmesh, math
from mathutils import Vector, Matrix

SRC = r"E:/godot_game_by_fable/001/art/models/nezha_opt.glb"
OUT = r"E:/godot_game_by_fable/art_tmp/nezha_v2.glb"

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
RIG = bpy.data.objects["rig"]
OLD = bpy.data.objects["nezha_body"]
MATS = [m for m in OLD.data.materials]          # slot0=VCol, slot1=sash
assert len(MATS) >= 2, [m.name for m in MATS]
print("materials:", [m.name for m in MATS])

B = RIG.data.bones
def bm(name):
    return RIG.matrix_world @ B[name].matrix_local
def bl(name):
    return B[name].length
def bpt(name, t=0.0):
    M = bm(name)
    return M @ Vector((0.0, t * B[name].length, 0.0))

PAL = {"white":(1.0,1.0,1.0), "gold":(0.847,0.617,0.120), "red":(0.701,0.100,0.070),
       "black":(0.050,0.040,0.050), "dred":(0.552,0.060,0.050), "skin":(0.922,0.723,0.597),
       "pale":(0.922,0.888,0.839), "leath":(0.150,0.060,0.050)}

V=[]; F=[]; VC=[]; W=[]
def add(verts, faces, color, weights, mat=0, vcol=None):
    n=len(verts)
    if isinstance(weights, dict): weights=[weights]*n
    elif len(weights)==n: pass
    elif len(weights)==1: weights=[weights[0]]*n
    elif n%2==0 and len(weights)==n//2: weights=[weights[i//2] for i in range(n)]
    else: weights=[weights[min(i,len(weights)-1)] for i in range(n)]
    assert len(weights)==n, (len(weights), n)
    off=len(V); V.extend(verts)
    VC.extend([vcol if vcol else PAL[color]]*len(verts))
    W.extend(weights)
    for f in faces: F.append((tuple(i+off for i in f), mat))

def ring(c, ax, az, rx, rz, n, ph=0.0):
    return [c + ax*(rx*math.cos(ph+2*math.pi*i/n)) + az*(rz*math.sin(ph+2*math.pi*i/n)) for i in range(n)]

def bridge_faces(nrings, n, cap0=False, cap1=False):
    faces=[]
    for i in range(nrings-1):
        a=i*n; b=(i+1)*n
        for k in range(n):
            k2=(k+1)%n
            faces.append((a+k, a+k2, b+k2, b+k))
    if cap0: faces.append(tuple(range(n-1,-1,-1)))
    if cap1:
        last=(nrings-1)*n; faces.append(tuple(range(last,last+n)))
    return faces

def tube(rings_pts, color, weights, mat=0, caps=(True,True), n=None):
    n = n or len(rings_pts[0])
    verts=[p for r in rings_pts for p in r]
    add(verts, bridge_faces(len(rings_pts), n, caps[0], caps[1]), color, weights, mat)

def sphere(center, rx, ry, rz, color, weights, mat=0, segs=16, rings=10,
           squash_front=1.0, ycut=None, hsc=1.0):
    verts=[]; faces=[]
    grid=[]
    for j in range(rings+1):
        phi=math.pi*j/rings
        s=math.sin(phi); c=math.cos(phi)
        yw = center.y - ry*c
        if ycut is not None and yw > ycut:
            grid.append(None); continue
        row=[]
        for i in range(segs):
            th=2*math.pi*i/segs
            x = center.x + rx*s*math.cos(th)
            z = center.z + rz*s*math.sin(th)
            if s*math.sin(th) < 0:      # 前侧(-z)压扁一点
                z = center.z + rz*s*math.sin(th)*squash_front
            v=Vector((x, yw, z))
            v.y = center.y - ry*c*hsc
            row.append(len(verts)); verts.append(v)
        grid.append(row)
    # build faces from non-empty rows
    rows=[r for r in grid if r]
    idx=0
    def ring_idx(ri):
        # global index offset of row ri among non-empty rows
        return sum(len(rr) for rr in rows[:ri])
    for ri in range(len(rows)-1):
        a=ring_idx(ri); b=ring_idx(ri+1)
        for k in range(segs):
            k2=(k+1)%segs
            faces.append((a+k, a+k2, b+k2, b+k))
    add(verts, faces, color, weights, mat)
    return verts

def torus(center, R, r, axis, color, weights, mat=0, segs=24, tsegs=8, color2=None):
    ax = axis.normalized()
    up = Vector((0,-1,0))
    if abs(ax.dot(up))>0.9: up=Vector((0,0,1))
    u = ax.cross(up).normalized(); v = ax.cross(u).normalized()
    rings_pts=[]
    for i in range(segs):
        th=2*math.pi*i/segs
        c = center + u*(R*math.cos(th)) + v*(R*math.sin(th))
        rad = (u*math.cos(th) + v*math.sin(th))
        pts=[c + rad*(r*math.cos(2*math.pi*j/tsegs)) + ax*(r*math.sin(2*math.pi*j/tsegs)) for j in range(tsegs)]
        rings_pts.append(pts)
    verts=[p for rp in rings_pts for p in rp]
    faces=[]
    for i in range(segs):
        a=i*tsegs; b=((i+1)%segs)*tsegs
        for j in range(tsegs):
            j2=(j+1)%tsegs
            faces.append((a+j, a+j2, b+j2, b+j))
    add(verts, faces, color, weights, mat)

def ribbon(pts, widths, normal, color, weights, mat=1, thick=0.006):
    """双面薄带：pts 中心线，widths 半宽，normal 展宽方向"""
    n=len(pts); fr=[]; bk=[]
    for i,p in enumerate(pts):
        nv = normal[i] if isinstance(normal, list) else normal
        fr.append(p + nv*widths[i]); bk.append(p - nv*widths[i])
    verts = fr+bk
    off_b = n
    faces=[]
    for i in range(n-1):
        faces.append((i, i+1, off_b+i+1, off_b+i))
    add(verts, faces, color, weights, mat)

# ============ 躯干 ============
def sm(x): return x*x*(3-2*x)

def sector_panel(th, hw, rows, color, weights, mat=0, cols=4, zs=0.88):
    """一块扇形布片：rows=[(y, r, zs)]，双面。"""
    pts=[]
    for (y,r,z) in rows:
        for c in range(cols):
            a = th - hw + 2*hw*c/(cols-1)
            pts.append(Vector((r*math.cos(a), y, r*z*math.sin(a))))
    faces=[]; n=len(rows)
    for i in range(n-1):
        for c in range(cols-1):
            a=i*cols+c; b=a+1; d=(i+1)*cols+c; e=d+1
            faces += [(a,b,d),(b,e,d),(a,d,b),(b,d,e)]
    add(pts, faces, color, weights, mat=mat)
SEC = [(-0.845,0.142,0.108),(-0.90,0.138,0.104),(-0.965,0.124,0.096),(-1.032,0.106,0.084),
       (-1.10,0.128,0.096),(-1.19,0.158,0.112),(-1.28,0.176,0.122),(-1.355,0.184,0.124),
       (-1.408,0.178,0.118),(-1.445,0.146,0.098)]
CN=16
rings_pts=[]
for (y,rx,rz) in SEC:
    c=Vector((0,y,0)); rings_pts.append(ring(c, Vector((1,0,0)), Vector((0,0,1)), rx, rz, CN))
wlist=[]
for (y,rx,rz) in SEC:
    t=(y+0.855)/(-1.442+0.855)
    wch=sm(min(1.0,max(0.0,(t-0.10)/0.50)))
    w={"hips":1.0-wch, "chest":wch}
    if t>0.90:
        k=(t-0.90)/0.10*0.35; w={"hips":0.0,"chest":wch*(1-k),"neck":k}
    wlist.append([w]*CN)
ver=[p for r in rings_pts for p in r]; wflat=[w for wl in wlist for w in wl]
add(ver, bridge_faces(len(rings_pts), CN, True, True), "red", wflat)

# 肩甲
for s in (-1,1):
    sphere(Vector((s*0.198,-1.398,0.008)), 0.098,0.086,0.096, "red", [{"chest":1.0}], segs=16, rings=10)
    torus(Vector((s*0.204,-1.404,0.004)), 0.094, 0.016, Vector((s*0.55,0.12,-1)).normalized(), "gold", [{"chest":1.0}], segs=20, tsegs=6)
# 胸口金饰 + 腰带
torus(Vector((0,-1.268,-0.004)), 0.170, 0.014, Vector((1,0,0)).normalized(), "gold", [{"chest":1.0}], segs=28, tsegs=6)
torus(Vector((0,-1.036,-0.004)), 0.112, 0.024, Vector((0.05,0.05,1)).normalized(), "gold", [{"hips":0.5,"chest":0.5}], segs=26, tsegs=6)
sphere(Vector((0,-1.030,-0.098)), 0.042,0.040,0.030, "gold", [{"hips":0.5,"chest":0.5}], segs=12, rings=8)
# 领口
torus(Vector((0,-1.452,0.0)), 0.062, 0.016, Vector((0,-1,0)), "gold", [{"chest":0.7,"neck":0.3}], segs=20, tsegs=6)

# ============ 颈 / 头 ============
neck_rings=[]
for t in (0.0,0.5,1.0):
    p = bpt("neck", t); neck_rings.append(ring(p, Vector((1,0,0)), Vector((0,0,1)), 0.046-0.004*t, 0.042-0.004*t, 12))
nw=[{"neck":0.4,"chest":0.6}]*12+[{"neck":1.0}]*12+[{"neck":0.5,"head":0.5}]*12
add([p for r in neck_rings for p in r], bridge_faces(3,12,True,True), "skin", nw)

HEAD=Vector((0.0,-1.706,-0.006)); HR=(0.134,0.144,0.150)
sphere(HEAD, HR[0],HR[1],HR[2], "skin", [{"head":1.0}], segs=20, rings=14, squash_front=0.94)
# 下巴收窄
for i,v in enumerate(V):
    pass  # 已由 sphere 参数控制，后续微调留待下一版
# 耳朵
for s in (-1,1):
    sphere(Vector((s*0.137,-1.710,-0.004)), 0.020,0.038,0.032, "skin", [{"head":1.0}], segs=10, rings=7)
# 鼻
sphere(Vector((0,-1.706,-0.148)), 0.017,0.022,0.022, "skin", [{"head":1.0}], segs=10, rings=7)
# 眼白 + 瞳孔 + 眉 + 嘴
for s in (-1,1):
    ec=Vector((s*0.056,-1.722,-0.118))
    sphere(ec, 0.044,0.038,0.040, "white", [{"head":1.0}], segs=16, rings=10)
    sphere(ec+Vector((s*0.006,-0.004,-0.026)), 0.023,0.021,0.021, "black", [{"head":1.0}], segs=14, rings=9)
    sphere(ec+Vector((s*0.014,-0.012,-0.032)), 0.010,0.010,0.010, "white", [{"head":1.0}], segs=8, rings=6)
    # 眉（细长方块，斜置）
    bx=Vector((s*0.058,-1.762,-0.116))
    for k in range(3):
        cc = bx + Vector((s*(k-1)*0.016, 0.0, (k-1)*(-s)*0.006*(-s)))
        sphere(cc, 0.011,0.006,0.005, "black", [{"head":1.0}], segs=8, rings=6)
# 嘴
sphere(Vector((0,-1.652,-0.140)), 0.022,0.011,0.007, "black", [{"head":1.0}], segs=10, rings=6)

# ============ 头发 ============
sphere(HEAD+Vector((0,0.012,0.004)), 0.141,0.147,0.153, "black", [{"head":1.0}], segs=22, rings=16, ycut=-1.752)
# 前额刘海：三片
for k,s in enumerate((-1.0,0.0,1.0)):
    sphere(HEAD+Vector((s*0.060,-0.030,-0.136+abs(s)*0.018)), 0.054,0.046,0.040, "black", [{"head":1.0}], segs=14, rings=9)
# 双丸子
for s in (-1,1):
    sphere(Vector((s*0.082,-1.898,-0.004)), 0.058,0.056,0.056, "black", [{"head":1.0}], segs=16, rings=10)
    torus(Vector((s*0.082,-1.842,-0.004)), 0.034, 0.011, Vector((0.15*s,-0.2,1)).normalized(), "red", [{"head":1.0}], segs=14, tsegs=6)

# ============ 手臂 ============
for side in ("L","R"):
    sg = -1.0 if side=="L" else 1.0
    ua, fa, hd = f"upper_arm.{side}", f"forearm.{side}", f"hand.{side}"
    # 上臂（红袖）
    ts=[0.0,0.12,0.35,0.6,0.85,1.0]; rr=[0.086,0.084,0.074,0.064,0.056,0.052]
    M=bm(ua); ax=(M.to_3x3()@Vector((1,0,0))).normalized(); az=(M.to_3x3()@Vector((0,0,1))).normalized()
    pts=[bpt(ua,t) for t in ts]; wl=[]
    for t in ts:
        k=max(0.0,(t-0.78)/0.22)*0.45
        wl.append([{"upper_arm."+side:1.0-k} for _ in range(0)] )
    wl=[]
    for t in ts:
        k=max(0.0,(t-0.78)/0.22)*0.45
        wl.append({"upper_arm."+side:1.0-k, "forearm."+side:k} if k>0 else {"upper_arm."+side:1.0})
    wflat=[w for i in range(len(pts)) for w in [wl[i]]*CN]
    tube([ring(pts[i], ax, az, rr[i], rr[i]*0.92, CN) for i in range(len(pts))], "red", wflat)
    # 喇叭袖口（垂坠外扩）
    tube([ring(bpt(ua,0.62), ax, az, 0.070, 0.066, 14), ring(bpt(ua,0.80), ax, az, 0.082, 0.078, 14),
          ring(bpt(ua,0.98), ax, az, 0.092, 0.086, 14)],
         "red", [{"upper_arm."+side:1.0}]*42)
    # 肘
    sphere(bpt(ua,1.0), 0.052,0.052,0.050, "red", [{"upper_arm."+side:0.5,"forearm."+side:0.5}], segs=12, rings=8)
    # 前臂（红袖 + 白护腕）
    ts2=[0.0,0.25,0.6,0.82,1.0]; rr2=[0.054,0.050,0.046,0.048,0.052]
    M2=bm(fa); ax2=(M2.to_3x3()@Vector((1,0,0))).normalized(); az2=(M2.to_3x3()@Vector((0,0,1))).normalized()
    pts2=[bpt(fa,t) for t in ts2]; wl2=[]
    for t in ts2:
        k=max(0.0,(t-0.80)/0.20)*0.4
        wl2.append({"forearm."+side:1.0-k, "hand."+side:k} if k>0 else {"forearm."+side:1.0})
    tube([ring(pts2[i], ax2, az2, rr2[i], rr2[i]*0.92, CN) for i in range(len(pts2))], "red",
         [w for i in range(len(pts2)) for w in [wl2[i]]*CN])
    # 白护腕
    tube([ring(bpt(fa,0.86), ax2, az2, 0.056, 0.052, 12), ring(bpt(fa,1.0), ax2, az2, 0.052, 0.048, 12)],
         "pale", [{"forearm."+side:0.7,"hand."+side:0.3}]*24)
    # 手：手掌 + 5 指
    Mh=bm(hd); hx=(Mh.to_3x3()@Vector((1,0,0))).normalized(); hz=(Mh.to_3x3()@Vector((0,0,1))).normalized()
    hy=(Mh.to_3x3()@Vector((0,1,0))).normalized()
    palm_c = bpt(hd,0.15)
    sphere(palm_c, 0.040,0.052,0.024, "skin", [{"hand."+side:1.0}], segs=12, rings=8)
    for fi in range(4):
        off = (fi-1.5)*0.019
        base = palm_c + hx*off + hy*0.030
        ln = 0.040 if fi in (1,2) else 0.034
        for seg in range(2):
            c = base + hy*(ln*(seg*0.95)) + hz*(-0.004*seg)
            sphere(c, 0.0105, ln*0.55, 0.0105, "skin", [{"hand."+side:1.0}], segs=8, rings=6)
    # 拇指
    sphere(palm_c + hx*(0.036*(-1)) + hy*0.012 + hz*(-0.010), 0.013,0.020,0.012, "skin", [{"hand."+side:1.0}], segs=8, rings=6)

# ============ 腿 / 靴 / 风火轮 ============
for side in ("L","R"):
    th, sh, ft = f"thigh.{side}", f"shin.{side}", f"foot.{side}"
    ts=[0.0,0.2,0.5,0.8,1.0]; rr=[0.100,0.094,0.082,0.072,0.066]
    M=bm(th); ax=(M.to_3x3()@Vector((1,0,0))).normalized(); az=(M.to_3x3()@Vector((0,0,1))).normalized()
    pts=[bpt(th,t) for t in ts]; wl=[]
    for t in ts:
        k=max(0.0,(t-0.80)/0.20)*0.45
        wl.append({"thigh."+side:1.0-k, "shin."+side:k} if k>0 else {"thigh."+side:1.0})
    tube([ring(pts[i], ax, az, rr[i], rr[i]*0.95, CN) for i in range(len(pts))], "dred",
         [w for i in range(len(pts)) for w in [wl[i]]*CN])
    sphere(bpt(th,1.0), 0.062,0.060,0.060, "dred", [{"thigh."+side:0.5,"shin."+side:0.5}], segs=12, rings=8)
    # 小腿 + 靴
    ts2=[0.0,0.15,0.45,0.75,0.95]; rr2=[0.068,0.072,0.066,0.058,0.054]
    M2=bm(sh); ax2=(M2.to_3x3()@Vector((1,0,0))).normalized(); az2=(M2.to_3x3()@Vector((0,0,1))).normalized()
    pts2=[bpt(sh,t) for t in ts2]; wl2=[]
    for t in ts2:
        k=max(0.0,(t-0.85)/0.15)*0.4
        wl2.append({"shin."+side:1.0-k, "foot."+side:k} if k>0 else {"shin."+side:1.0})
    tube([ring(pts2[i], ax2, az2, rr2[i], rr2[i]*0.95, CN) for i in range(len(pts2))], "leath",
         [w for i in range(len(pts2)) for w in [wl2[i]]*CN])
    # 靴口金环
    torus(bpt(sh,0.06), 0.066, 0.014, (bpt(sh,0.2)-bpt(sh,0.0)).normalized(), "gold", [{"shin."+side:1.0}], segs=16, tsegs=6)
    # 脚：自踝向前
    ank=bpt(sh,0.98); toe=ank+Vector((0,-0.010,-0.150))
    fr=[]; 
    for t in (0.0,0.45,0.8,1.0):
        c=ank.lerp(toe,t); r=0.048-0.014*t
        fr.append(ring(c, Vector((1,0,0)), Vector((0,-1,0)), r, r*0.85, 12))
    tube(fr, "leath", [{"foot."+side:0.4,"shin."+side:0.6}]*48)
    sphere(toe, 0.032,0.030,0.028, "gold", [{"foot."+side:1.0}], segs=12, rings=8)
    # 风火轮：轴沿 X，绕踝
    cen = Vector((0.118*(-1 if side=="L" else 1), -0.03, -0.045))
    torus(cen, 0.196, 0.028, Vector((1,0,0)), "gold", [{"foot."+side:1.0}], segs=32, tsegs=8)
    torus(cen, 0.150, 0.014, Vector((1,0,0)), "red", [{"foot."+side:1.0}], segs=26, tsegs=6)
    sphere(cen, 0.036,0.036,0.036, "gold", [{"foot."+side:1.0}], segs=12, rings=8)
    for k in range(6):
        th=2*math.pi*k/6
        dirv=Vector((0,-1,0))*math.cos(th)+Vector((0,0,1))*math.sin(th)
        a=cen+dirv*0.034; b=cen+dirv*0.186
        mid=(a+b)*0.5; ln=(b-a).length
        fr=[ring(a, Vector((1,0,0)), Vector((0,0,1)).cross(dirv).normalized(), 0.011, 0.011, 8),
            ring(b, Vector((1,0,0)), Vector((0,0,1)).cross(dirv).normalized(), 0.008, 0.008, 8)]
        tube(fr, "gold", [{"foot."+side:1.0}]*16)

# ============ 裙摆 ============
# 内层（短、深红）
NP=16
for k in range(NP):
    th=2*math.pi*(k+0.5)/NP; hw=(math.pi/NP)*0.94
    rows=[(y, r, 0.88) for (y,r) in ((-0.836,0.140),(-0.900,0.176),(-0.965,0.206),(-1.020,0.222))]
    sector_panel(th, hw, rows, "dred", {"hips":1.0})
# 外层（长、正红，错开半格，下摆更长）
for k in range(NP):
    th=2*math.pi*k/NP; hw=(math.pi/NP)*0.90
    rows=[(y, r, 0.88) for (y,r) in ((-0.830,0.146),(-0.890,0.188),(-0.960,0.226),(-1.045,0.256),(-1.125,0.272))]
    sector_panel(th, hw, rows, "red", {"hips":1.0})
# 前襟两条飘带（下摆尖）
for s in (-1,1):
    sector_panel(math.pi*0.5+s*0.10, 0.075,
                 [(-0.840,0.150,0.90),(-0.930,0.200,0.90),(-1.060,0.238,0.90),(-1.190,0.252,0.90)],
                 "red", {"hips":1.0}, cols=3)

# ============ 乾坤圈 ============
torus(Vector((0,-1.02,0.02)), 0.255, 0.016, Vector((0.25,0.15,1)).normalized(), "gold", [{"chest":1.0}], segs=30, tsegs=6)

# ============ 混天绫（沿 rib 骨骼，材质 1 = 丝绸） ============
for side in ("L","R"):
    chain=[f"rib.{side}.1", f"rib.{side}.2", f"rib.{side}.3"]
    pts=[]; wl=[]
    for bi,bn in enumerate(chain):
        for t in (0.0,0.34,0.67,1.0):
            pts.append(bpt(bn,t))
            k = 0.0
            if t>0.75 and bi<2: k=0.35
            elif t<0.25 and bi>0: k=0.35
            w={"rib.%s.%d"%(side, bi+1 if t>0.25 else max(1,bi)):1.0}
            if k>0:
                w={"rib.%s.%d"%(side,bi+1):1.0-k, "rib.%s.%d"%(side, min(3,bi+2) if t>0.75 else bi):k}
            wl.append(w)
    # 抖动 + 双幅
    for layer,off in ((0,0.016),(1,-0.016)):
        nv=[]
        prev=None
        for i,p in enumerate(pts):
            d = (pts[min(len(pts)-1,i+1)]-pts[max(0,i-1)])
            side_v = Vector((0,-1,0)).cross(d.normalized()).normalized()
            wob = math.sin(i*1.35+layer*2.2)*0.11
            nv.append((side_v + Vector((0,0,1))*wob).normalized())
        pp=[Vector((p.x*0.66, p.y + 0.02*math.sin(i*0.9), p.z)) + nv[i]*off for i,p in enumerate(pts)]
        wid=[0.046*(0.45+0.55*math.sin(i/(len(pp)-1)*math.pi)) for i in range(len(pp))]
        ribbon(pp, wid, nv, "red", wl, mat=1)

# ============ 火尖枪（系在胸口） ============
shaft_a=Vector((0.20,-0.62,0.24)); shaft_b=Vector((0.30,-1.70,0.30))
dirv=(shaft_b-shaft_a).normalized()
for t in (0.0,0.02,0.98,1.0):
    pass
rings_pts=[]
for t in (0.0,0.15,0.5,0.85,0.97):
    c=shaft_a.lerp(shaft_b,t); r=0.024
    rings_pts.append(ring(c, Vector((1,0,0)), Vector((0,0,1)).cross(dirv).normalized(), r, r, 10))
tube(rings_pts, "dred", [{"chest":0.7,"neck":0.3}]*50)
# 枪头
tip=shaft_b+dirv*0.16
rings_pts=[ring(shaft_b.lerp(tip,t), Vector((1,0,0)), Vector((0,0,1)).cross(dirv).normalized(), 0.030*(1-t)+0.002, 0.030*(1-t)+0.002, 10) for t in (0.0,0.4,0.75,1.0)]
tube(rings_pts, "gold", [{"chest":0.7,"neck":0.3}]*40)
torus(shaft_b, 0.030, 0.008, dirv, "gold", [{"chest":1.0}], segs=12, tsegs=5)

print("VERTS", len(V), "FACES", len(F), "WEIGHTS", len(W), "VCOL", len(VC))
assert len(W)==len(V) and len(VC)==len(V)

# ---------- 建 mesh ----------
for o in list(bpy.data.objects):
    if o.type=='MESH': bpy.data.objects.remove(o, do_unlink=True)
me = bpy.data.meshes.new("nezha_body2")
me.from_pydata([tuple(v) for v in V], [], [f[0] for f in F])
me.update()
ob = bpy.data.objects.new("nezha_body2", me)
bpy.context.scene.collection.objects.link(ob)
for m in MATS[:2]: me.materials.append(m)
for i,(idx,mat) in enumerate(F):
    me.polygons[i].material_index = mat
ca = me.color_attributes.new("Color", 'BYTE_COLOR', 'CORNER')
for li,loop in enumerate(me.loops):
    c = VC[loop.vertex_index]
    ca.data[li].color = (c[0],c[1],c[2],1.0)

# 顶点组
names=set()
for w in W: names.update(w.keys())
grp={n: ob.vertex_groups.new(name=n) for n in names}
for vi,w in enumerate(W):
    tot=sum(w.values()) or 1.0
    for n,val in w.items():
        if val>0: grp[n].add([vi], val/tot, 'REPLACE')

ob.parent = RIG
ob.matrix_parent_inverse = RIG.matrix_world.inverted()
md = ob.modifiers.new("Armature", 'ARMATURE'); md.object = RIG
bpy.context.view_layer.objects.active = ob
ob.select_set(True)

# 平滑
bpy.ops.object.shade_smooth()
try:
    ob.data.use_auto_smooth = True
    ob.data.auto_smooth_angle = math.radians(55)
except Exception as e:
    print("auto_smooth skip:", e)

bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', use_selection=False,
                          export_tangents=True, export_skins=True, export_yup=True,
                          export_apply=False, export_animations=False)
print("EXPORTED", OUT)
print("bbox:", tuple(round(x,3) for x in ob.dimensions))
