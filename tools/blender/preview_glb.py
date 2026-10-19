"""把单个 GLB 导入 Blender，打灯、取景、EEVEE 渲染一张预览图。

用法：
  blender --background --factory-startup --python preview_glb.py -- 模型.glb 输出.png [角度]
角度 = 相机水平方位角（度），默认 35。
"""
import math
import os
import sys

import bpy
import mathutils

OUT_W, OUT_H = 640, 900


def clear():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.images):
        for item in list(block):
            if item.users == 0:
                try:
                    block.remove(item)
                except Exception:
                    pass


def scene_bounds():
    mn = mathutils.Vector((1e9, 1e9, 1e9))
    mx = mathutils.Vector((-1e9, -1e9, -1e9))
    found = False
    for ob in bpy.context.scene.objects:
        if ob.type != "MESH":
            continue
        found = True
        for c in ob.bound_box:
            w = ob.matrix_world @ mathutils.Vector(c)
            mn = mathutils.Vector((min(mn.x, w.x), min(mn.y, w.y), min(mn.z, w.z)))
            mx = mathutils.Vector((max(mx.x, w.x), max(mx.y, w.y), max(mx.z, w.z)))
    if not found:
        mn, mx = mathutils.Vector((0, 0, 0)), mathutils.Vector((1, 1, 1))
    return mn, mx


def main():
    argv = sys.argv
    args = argv[argv.index("--") + 1:] if "--" in argv else []
    src = args[0]
    dst = args[1]
    yaw = float(args[2]) if len(args) > 2 else 35.0

    clear()
    bpy.ops.import_scene.gltf(filepath=src)

    mn, mx = scene_bounds()
    center = (mn + mx) * 0.5
    size = mx - mn
    radius = max(size.x, size.y, size.z)

    world = bpy.data.worlds.new("W") if not bpy.data.worlds else bpy.data.worlds[0]
    bpy.context.scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs[0].default_value = (0.06, 0.09, 0.13, 1.0)
        bg.inputs[1].default_value = 1.2

    # 主光 + 侧光 + 顶光，模拟游戏里"从上方打下来"的冷光
    for name, rot, energy, color in (
        ("key", (math.radians(58), 0, math.radians(yaw + 40)), 6.0, (0.85, 0.93, 1.0)),
        ("fill", (math.radians(70), 0, math.radians(yaw - 110)), 2.0, (0.5, 0.65, 0.9)),
        ("rim", (math.radians(115), 0, math.radians(yaw + 180)), 3.0, (0.7, 0.85, 1.0)),
    ):
        ld = bpy.data.lights.new(name, "SUN")
        ld.energy = energy
        ld.color = color
        lo = bpy.data.objects.new(name, ld)
        lo.rotation_euler = rot
        bpy.context.scene.collection.objects.link(lo)

    cam_d = bpy.data.cameras.new("cam")
    cam_d.lens = 60
    cam = bpy.data.objects.new("cam", cam_d)
    bpy.context.scene.collection.objects.link(cam)
    bpy.context.scene.camera = cam

    dist = radius * 2.3
    ang = math.radians(yaw)
    cam.location = center + mathutils.Vector(
        (math.sin(ang) * dist, -math.cos(ang) * dist, radius * 0.05))
    direction = center - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()

    sc = bpy.context.scene
    try:
        sc.render.engine = "BLENDER_EEVEE_NEXT"   # Blender 4.2~5.0
    except TypeError:
        sc.render.engine = "BLENDER_EEVEE"        # Blender 5.1 的枚举名
    sc.render.resolution_x = OUT_W
    sc.render.resolution_y = OUT_H
    sc.render.film_transparent = False
    sc.view_settings.view_transform = "Standard"
    sc.render.filepath = dst
    sc.render.image_settings.file_format = "PNG"
    bpy.ops.render.render(write_still=True)

    print("[preview]", os.path.basename(src),
          "bounds", [round(v, 3) for v in size],
          "->", dst, flush=True)


if __name__ == "__main__":
    main()
