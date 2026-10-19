"""确定 nezha.glb 的正确站立朝向：同一模型按 4 个绕 X 的角度各渲一张正视，
文件名带角度，肉眼挑出"头朝上"的那张。
用法：
  blender --background --factory-startup --python orient_check.py -- <glb> <out_prefix>
"""

import math
import os
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
GLB = argv[0] if argv else "E:/godot_game_by_fable/001/art/models/nezha.glb"
PREFIX = argv[1] if len(argv) > 1 else "E:/godot_game_by_fable/_baseline/ori"

# ---- 清场
for ob in list(bpy.data.objects):
    bpy.data.objects.remove(ob, do_unlink=True)

bpy.ops.import_scene.gltf(filepath=GLB)
roots = [o for o in bpy.data.objects if o.parent is None]


def body_mesh():
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    meshes = [o for o in meshes if [m for m in o.data.materials if m]]
    return max(meshes, key=lambda o: len(o.data.polygons))


body = body_mesh()
for ob in [o for o in bpy.data.objects if o.type == "MESH" and o is not body]:
    ob.hide_render = True


def bounds(objs):
    mn = Vector((1e9, 1e9, 1e9))
    mx = Vector((-1e9, -1e9, -1e9))
    for ob in objs:
        for c in ob.bound_box:
            w = ob.matrix_world @ Vector(c)
            mn = Vector((min(mn.x, w.x), min(mn.y, w.y), min(mn.z, w.z)))
            mx = Vector((max(mx.x, w.x), max(mx.y, w.y), max(mx.z, w.z)))
    return mn, mx


sc = bpy.context.scene
sc.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in [
    e.identifier for e in sc.render.bl_rna.properties["engine"].enum_items
] else "BLENDER_WORKBENCH"
sc.render.resolution_x = 520
sc.render.resolution_y = 640
sc.world = bpy.data.worlds.new("W") if sc.world is None else sc.world
bg = sc.world.node_tree.nodes.get("Background")
if bg:
    bg.inputs[0].default_value = (0.18, 0.2, 0.24, 1.0)
    bg.inputs[1].default_value = 1.2

cam_data = bpy.data.cameras.new("Cam")
cam_data.type = "ORTHO"
cam = bpy.data.objects.new("Cam", cam_data)
bpy.context.collection.objects.link(cam)
sc.camera = cam

for rx in (0, 90, -90, 180):
    for ob in roots:
        ob.rotation_mode = "XYZ"
        ob.rotation_euler = (math.radians(rx), 0, 0)
    bpy.context.view_layer.update()
    mn, mx = bounds([body])
    size = mx - mn
    center = (mn + mx) * 0.5
    aspect = sc.render.resolution_x / float(sc.render.resolution_y)
    cam_data.ortho_scale = max(size.z, size.x / aspect) * 1.12
    cam.location = center + Vector((0, -6, 0))
    cam.rotation_euler = (math.radians(90), 0, 0)

    for name, loc, energy in [("k", Vector((-2, -3, 2)), 900),
                              ("f", Vector((3, -2, 0.5)), 350),
                              ("r", Vector((0, 3, 2)), 500)]:
        lp = bpy.data.lights.get(name) or bpy.data.lights.new(name, "AREA")
        lp.energy = energy
        lp.size = 4.0
        lo = bpy.data.objects.get(name) or bpy.data.objects.new(name, lp)
        if lo.name not in bpy.context.collection.objects:
            bpy.context.collection.objects.link(lo)
        lo.location = center + loc
        d = (center - lo.location).normalized()
        lo.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()

    sc.render.filepath = "%s_rx%+d.png" % (PREFIX, rx)
    bpy.ops.render.render(write_still=True)
    print("[ori] rx %+d  bbox x %.3f y %.3f z %.3f  -> %s"
          % (rx, size.x, size.y, size.z, sc.render.filepath))

print("[ori] done")
