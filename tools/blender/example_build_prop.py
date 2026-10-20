"""Headless example: build a game-ready prop, render a preview, export GLB.

Run:
    E:\\blender\\app\\blender.exe --background --factory-startup --python example_build_prop.py

Outputs (next to this script, in out/):
    crystal_prop.glb   - import straight into Godot
    crystal_prop.png   - preview render
    crystal_prop.blend - editable source

Notes for Blender 5.x:
  * node names are localized by UI language -> always look up by bl_idname
  * render engine enum only exposes BLENDER_EEVEE; CYCLES/WORKBENCH are set by id
"""
import bpy
import json
import math
import mathutils
import os

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
os.makedirs(OUT, exist_ok=True)

report = {}


# ---------------------------------------------------------------- helpers
def principled(mat):
    for n in mat.node_tree.nodes:
        if n.bl_idname == "ShaderNodeBsdfPrincipled":
            return n
    return None


def set_input(node, names, value):
    """Set the first matching socket name (handles localized / renamed sockets)."""
    for name in names:
        if name in node.inputs:
            node.inputs[name].default_value = value
            return True
    return False


def make_mat(name, base, metallic=0.0, rough=0.4, emission=None, strength=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = principled(m)
    if b:
        set_input(b, ["Base Color", "Base color"], base)
        set_input(b, ["Metallic"], metallic)
        set_input(b, ["Roughness"], rough)
        if emission is not None:
            set_input(b, ["Emission Color", "Emission"], emission)
            set_input(b, ["Emission Strength"], strength)
    return m


def look_at(obj, target=(0.0, 0.0, 0.0)):
    direction = mathutils.Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def clear_scene():
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.lights, bpy.data.cameras):
        for item in list(block):
            if item.users == 0:
                block.remove(item)


# ---------------------------------------------------------------- scene
clear_scene()
scene = bpy.context.scene

crystal = make_mat(
    "M_Crystal", (0.08, 0.75, 0.95, 1), metallic=0.15, rough=0.12,
    emission=(0.0, 0.75, 1.0, 1), strength=3.0,
)
rock = make_mat("M_Rock", (0.14, 0.15, 0.18, 1), metallic=0.0, rough=0.75)
rim = make_mat(
    "M_Rim", (0.6, 0.85, 1.0, 1), metallic=0.6, rough=0.2,
    emission=(0.4, 0.8, 1.0, 1), strength=1.2,
)

# --- rocky base
bpy.ops.mesh.primitive_cylinder_add(vertices=9, radius=1.05, depth=0.45, location=(0, 0, 0.225))
base = bpy.context.active_object
base.name = "Prop_Base"
base.data.materials.append(rock)

# --- crystal shards
shards = [
    ((0.0, 0.0, 0.95), 0.55, 2.1, (0.0, 0.0, 0.0)),
    ((0.42, 0.18, 0.72), 0.3, 1.35, (0.18, 0.12, math.radians(22))),
    ((-0.35, -0.22, 0.62), 0.26, 1.15, (-0.15, -0.1, math.radians(-26))),
]
for i, (loc, radius, depth, rot) in enumerate(shards):
    bpy.ops.mesh.primitive_cone_add(
        vertices=6, radius1=radius, radius2=radius * 0.22, depth=depth, location=loc
    )
    ob = bpy.context.active_object
    ob.name = f"Prop_Crystal_{i}"
    ob.rotation_euler = rot
    ob.data.materials.append(crystal)

# --- glowing ring for a bit of rim light
bpy.ops.mesh.primitive_torus_add(
    major_radius=1.12, minor_radius=0.035, location=(0, 0, 0.46)
)
ring_ob = bpy.context.active_object
ring_ob.name = "Prop_Ring"
ring_ob.data.materials.append(rim)

report["objects"] = [o.name for o in bpy.data.objects]

# --- stick every object origin at the world origin (nice pivot in Godot)
for ob in bpy.data.objects:
    if ob.type == "MESH":
        ob.select_set(True)
bpy.context.view_layer.objects.active = base
bpy.ops.object.origin_set(type="ORIGIN_CURSOR", center="MEDIAN")

# ---------------------------------------------------------------- world + light
world = bpy.data.worlds.new("PropWorld")
world.use_nodes = True
bg = world.node_tree.nodes.get("Background")
if bg:
    bg.inputs["Color"].default_value = (0.015, 0.02, 0.04, 1)
    bg.inputs["Strength"].default_value = 0.5
scene.world = world

bpy.ops.object.light_add(type="AREA", location=(3.2, -3.0, 4.2))
key = bpy.context.active_object
key.name = "Light_Key"
key.data.energy = 900
key.data.size = 3.0
look_at(key, (0, 0, 1.0))

bpy.ops.object.light_add(type="AREA", location=(-3.4, 1.6, 2.4))
fill = bpy.context.active_object
fill.name = "Light_Fill"
fill.data.energy = 300
fill.data.color = (0.35, 0.6, 1.0)
fill.data.size = 4.0
look_at(fill, (0, 0, 1.0))

# ---------------------------------------------------------------- camera
bpy.ops.object.camera_add(location=(4.6, -4.9, 3.1))
cam = bpy.context.active_object
cam.name = "PropCam"
cam.data.lens = 62
look_at(cam, (0.0, 0.0, 1.05))
scene.camera = cam

# ---------------------------------------------------------------- render
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 900
scene.render.resolution_y = 1100
scene.render.film_transparent = False
scene.render.image_settings.file_format = "PNG"
try:
    scene.eevee.taa_render_samples = 64
except Exception:
    pass
scene.view_settings.view_transform = "AgX" if "AgX" in [
    v.identifier for v in scene.view_settings.bl_rna.properties["view_transform"].enum_items
] else "Standard"

png = os.path.join(OUT, "crystal_prop.png")
scene.render.filepath = png
bpy.ops.render.render(write_still=True)
report["render"] = os.path.exists(png)
report["render_bytes"] = os.path.getsize(png) if os.path.exists(png) else 0

# ---------------------------------------------------------------- export
glb = os.path.join(OUT, "crystal_prop.glb")
bpy.ops.export_scene.gltf(filepath=glb, export_format="GLB", export_apply=True)
report["glb"] = os.path.exists(glb)
report["glb_bytes"] = os.path.getsize(glb) if os.path.exists(glb) else 0

blend = os.path.join(OUT, "crystal_prop.blend")
bpy.ops.wm.save_as_mainfile(filepath=blend)
report["blend"] = os.path.exists(blend)

# triangle count, useful when budgeting a mobile game
tris = 0
for ob in bpy.data.objects:
    if ob.type == "MESH":
        ob.data.calc_loop_triangles()
        tris += len(ob.data.loop_triangles)
report["triangles"] = tris
report["engines_ok"] = scene.render.engine

print("EXAMPLE_REPORT:" + json.dumps(report, ensure_ascii=False))
