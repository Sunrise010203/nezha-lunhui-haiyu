"""Fit the supplied rigid spear to the existing hand socket and export game art."""
import hashlib
import json
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

ROOT = Path('E:/godot_game_by_fable')
SOURCE = ROOT / 'art_source/weapons'
OUT = ROOT / '_review/huojianqiang'
OUT.mkdir(exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
path = SOURCE / 'source/huojianqiang.glb'
bpy.ops.import_scene.gltf(filepath=str(path))
body = next(o for o in bpy.context.scene.objects if o.type == 'MESH')
body.name = 'Huojianqiang'
body.data.transform(body.matrix_world)
body.matrix_world = Matrix.Identity(4)
points = np.array([list(v.co) for v in body.data.vertices])
grip_z = float(points[:, 2].min() + np.ptp(points[:, 2]) * .155)
handle = points[np.abs(points[:, 2] - grip_z) < .015]
grip = Vector((float(np.median(handle[:, 0])), float(np.median(handle[:, 1])), grip_z))
# Keep the established local grip at -0.25 and the blade tip at +1.27 metres.
scale = 1.52 / (float(points[:, 2].max()) - grip_z)
body.data.transform(Matrix.Translation((0, 0, -.25)) @ Matrix.Scale(scale, 4) @ Matrix.Translation(-grip))
bm = bmesh.new()
bm.from_mesh(body.data)
original_vertices = len(bm.verts)
bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=.000002)
bm.to_mesh(body.data)
bm.free()
body.data.update()
triangles = sum(len(p.vertices) - 2 for p in body.data.polygons)
modifier = body.modifiers.new('Game mesh - preserve original underneath', 'DECIMATE')
modifier.ratio = min(1, 45000 / triangles)
modifier.use_collapse_triangulate = True
for image in bpy.data.images:
    if image.users and image.source == 'FILE' and not image.packed_file:
        image.pack()
scene = bpy.context.scene
scene.name = 'Huojianqiang_Game_Weapon'
scene.render.engine = 'BLENDER_WORKBENCH'
scene.display.shading.color_type = 'TEXTURE'
scene.display.shading.show_cavity = False
scene.render.resolution_x, scene.render.resolution_y = 600, 1000
scene.render.resolution_percentage = 100
camera_data = bpy.data.cameras.new('WeaponReviewCamera')
camera = bpy.data.objects.new('WeaponReviewCamera', camera_data)
scene.collection.objects.link(camera)
scene.camera = camera
camera_data.type = 'ORTHO'
camera_data.ortho_scale = 2.05
target = Vector((0, 0, .38))
camera.location = target + Vector((0, -5, .05))
camera.rotation_euler = (target - camera.location).to_track_quat('-Z', 'Y').to_euler()
scene.render.filepath = str(OUT / 'game_front.png')
bpy.ops.render.render(write_still=True)
evaluated = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
mesh = evaluated.to_mesh()
optimized = np.array([list(v.co) for v in mesh.vertices])
game_triangles = sum(len(p.vertices) - 2 for p in mesh.polygons)
evaluated.to_mesh_clear()
report = {'source_sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
          'original_vertices': original_vertices, 'welded_vertices': len(body.data.vertices),
          'original_triangles': triangles, 'game_triangles': game_triangles,
          'source_grip': list(grip), 'scale': scale, 'local_grip_y': -.25,
          'bounds_z_up': [optimized.min(0).tolist(), optimized.max(0).tolist()],
          'textures': [{'name': i.name, 'size': list(i.size)} for i in bpy.data.images if i.packed_file]}
assert game_triangles <= 45010
assert abs(float(optimized[:, 2].max()) - 1.27) < .003
bpy.ops.object.select_all(action='DESELECT')
body.select_set(True)
bpy.context.view_layer.objects.active = body
assert bpy.ops.export_scene.gltf(filepath=str(ROOT / '001/art/models/huojianqiang.glb'),
    export_format='GLB', use_selection=True, export_yup=True, export_apply=True,
    export_animations=False, export_materials='EXPORT', export_cameras=False,
    export_lights=False) == {'FINISHED'}
bpy.data.orphans_purge(do_recursive=True)
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / 'huojianqiang.blend'), compress=True)
(OUT / 'asset_validation.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print('HUOJIANQIANG_READY', json.dumps(report), flush=True)
