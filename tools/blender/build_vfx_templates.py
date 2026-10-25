"""Build reusable VFX meshes with authored UVs, exports, previews and validation.
Run with Blender --background --factory-startup --python this_file.py.
"""
import bpy
import json
import math
from pathlib import Path
from mathutils import Vector
from collections import Counter

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'art_source/vfx_templates'
EXPORT = ROOT / '001/art/vfx/templates'
for path in (OUT, EXPORT, OUT / 'uv'):
    path.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = 1.0
assets = bpy.data.collections.new('VFX_Templates')
scene.collection.children.link(assets)
display = bpy.data.collections.new('Preview_Only')
scene.collection.children.link(display)


def material(name, color, metallic=0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    node = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    node.inputs['Base Color'].default_value = (*color, 1)
    node.inputs['Metallic'].default_value = metallic
    node.inputs['Roughness'].default_value = 0.55
    mat.use_backface_culling = False
    return mat


mats = [material('M_Arc_Preview', (0.9, 0.34, 0.07)),
        material('M_Ring_Preview', (0.07, 0.65, 0.48)),
        material('M_Cone_Preview', (0.06, 0.48, 0.85)),
        material('M_Dome_Preview', (0.42, 0.25, 0.8)),
        material('M_Bone_Preview', (0.83, 0.76, 0.55)),
        material('M_Stone_Preview', (0.25, 0.32, 0.39)),
        material('M_Bronze_Preview', (0.48, 0.28, 0.08), 0.65)]
records = []
objects = []


def add_mesh(name, verts, faces, uvfaces, mat, description, uv_note, smooth=True):
    mesh = bpy.data.meshes.new(name + '_Mesh')
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    assets.objects.link(obj)
    mesh.materials.append(mat)
    layer = mesh.uv_layers.new(name='UVMap')
    for poly, uvs in zip(mesh.polygons, uvfaces):
        poly.use_smooth = smooth
        for loop, uv in zip(poly.loop_indices, uvs):
            layer.data[loop].uv = uv
    obj['purpose'] = description
    obj['uv_contract'] = uv_note
    obj['origin_contract'] = 'Local origin is effect center/source; meters; Blender Z up, GLB/Godot Y up'
    objects.append(obj)
    records.append({'name': name, 'description': description, 'uv': uv_note})
    return obj


def surface(name, n, rows, fn, periodic, flip, mat, description, uv_note):
    cols = n if periodic else n + 1
    verts = [fn(i/n, j/rows) for i in range(cols) for j in range(rows+1)]
    faces, uvfaces = [], []
    for i in range(n):
        for j in range(rows):
            k = (i+1) % cols
            ids = [i*(rows+1)+j, k*(rows+1)+j,
                   k*(rows+1)+j+1, i*(rows+1)+j+1]
            uv = [(i/n, j/rows), ((i+1)/n, j/rows),
                  ((i+1)/n, (j+1)/rows), (i/n, (j+1)/rows)]
            if flip:
                ids.reverse()
                uv.reverse()
            faces.append(ids)
            uvfaces.append(uv)
    return add_mesh(name, verts, faces, uvfaces, mat, description, uv_note)


for name, sweep, width in [('fx_arc_narrow', 120, 0.22), ('fx_arc_wide', 200, 0.58)]:
    def arc(u, v, sweep=sweep, width=width):
        angle = math.radians(sweep)*(u-0.5)
        taper = 0.06 + 0.94*math.sin(math.pi*u)**0.7
        r = 1.25 + (v-0.5)*width*taper
        return (r*math.cos(angle), r*math.sin(angle), 0)
    surface(name, 48, 3, arc, False, True, mats[0],
            'Tapered slash arc; 1.25m center radius; sweep %s degrees' % sweep,
            'U follows arc start to end; V inner to outer edge. Pivot at circle center.')

surface('fx_ring_flat', 64, 3,
        lambda u,v: ((0.8+0.4*v)*math.cos(u*math.tau), (0.8+0.4*v)*math.sin(u*math.tau), 0),
        True, True, mats[1], 'Flat annulus; inner radius 0.8m, outer 1.2m',
        'U wraps circumference, seam at +X; V inner to outer edge.')
surface('fx_ring_wave', 64, 4,
        lambda u,v: ((0.8+0.4*v)*math.cos(u*math.tau), (0.8+0.4*v)*math.sin(u*math.tau),
                     0.18*math.sin(math.pi*v)),
        True, True, mats[1], 'Raised wave annulus; radii 0.8/1.2m, crest height 0.18m',
        'U wraps circumference, seam at +X; V inner to outer edge; crest at V=0.5.')

for name, radius in [('fx_cone_narrow', 0.48), ('fx_cone_wide', 1.15)]:
    surface(name, 32, 6,
            lambda u,v,r=radius: ((0.08+(r-0.08)*v)*math.cos(u*math.tau),
                                  (0.08+(r-0.08)*v)*math.sin(u*math.tau), 2*v),
            True, False, mats[2], 'Open tapered shell; length 2m; source radius 0.08m; mouth radius %sm' % radius,
            'U wraps circumference; V source to mouth; pivot at source; Blender +Z / Godot +Y axis.')

# Welded single pole with per-face UVs: no zero-area pole quads.
n, rows = 48, 12
verts = [(0,0,1)]
for j in range(1, rows+1):
    theta = math.pi/2*j/rows
    for i in range(n):
        phi = math.tau*i/n
        verts.append((math.sin(theta)*math.cos(phi), math.sin(theta)*math.sin(phi), math.cos(theta)))
faces, uvs = [], []
for i in range(n):
    faces.append([0, 1+i, 1+(i+1)%n])
    uvs.append([((i+0.5)/n,0), (i/n,1/rows), ((i+1)/n,1/rows)])
for j in range(1, rows):
    for i in range(n):
        a = 1+(j-1)*n+i
        b = 1+(j-1)*n+(i+1)%n
        c = 1+j*n+(i+1)%n
        d = 1+j*n+i
        faces.append([a,d,c,b])
        uvs.append([(i/n,j/rows),(i/n,(j+1)/rows),((i+1)/n,(j+1)/rows),((i+1)/n,j/rows)])
add_mesh('fx_dome', verts, faces, uvs, mats[3], 'Open hemisphere; radius 1m; outward normals; no bottom cap',
         'U longitude, V pole to rim; pole has UV singularity; pivot at sphere center/base plane.')


def shard(name, outline, thickness, mat, description):
    count = len(outline)
    verts = [(x,y,z-thickness/2) for x,y,z in outline]
    verts += [(x,y,z+thickness/2) for x,y,z in outline]
    faces = [list(reversed(range(count))), list(range(count, count*2))]
    faces += [[i,(i+1)%count,(i+1)%count+count,i+count] for i in range(count)]
    obj = add_mesh(name, verts, faces, [[(0,0)]*len(f) for f in faces], mat, description,
                   'Non-overlapping packed smart UV islands in 0..1; no directional scroll contract.', False)
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bevel = obj.modifiers.new('Small_edge_bevel', 'BEVEL')
    bevel.width = min(thickness*0.2, 0.018)
    bevel.segments = 1
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.035)
    bpy.ops.object.mode_set(mode='OBJECT')
    # Center geometry at bounding-box center for particle rotation.
    coords = [v.co for v in obj.data.vertices]
    center = Vector([(min(v[a] for v in coords)+max(v[a] for v in coords))/2 for a in range(3)])
    for v in obj.data.vertices:
        v.co -= center
    return obj


shard('fx_shard_bone', [(-.12,-.55,0),(.11,-.39,.015),(.13,.18,.07),(.04,.6,.13),
                      (-.07,.38,.09),(-.16,-.05,.025)], .09, mats[4], 'Curved tapered bone splinter; closed beveled mesh')
shard('fx_shard_stone', [(-.29,-.18,0),(.06,-.3,.03),(.3,-.08,-.02),(.22,.2,.04),
                       (-.04,.3,.08),(-.32,.11,.02)], .28, mats[5], 'Irregular stone fragment; closed beveled mesh')
shard('fx_shard_bronze', [(-.32,-.2,.025),(.15,-.24,0),(.34,.02,.04),(.09,.27,.10),
                        (-.28,.17,.06)], .045, mats[6], 'Bent thin bronze plate fragment; closed beveled mesh')


def uv_svg(obj):
    lines = ['<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">',
             '<rect width="1024" height="1024" fill="#18212a"/>',
             '<g fill="none" stroke="#6ce6c7" stroke-width="1">']
    uv = obj.data.uv_layers.active.data
    for p in obj.data.polygons:
        points = ' '.join(f'{16+uv[i].uv.x*992:.3f},{1008-uv[i].uv.y*992:.3f}' for i in p.loop_indices)
        lines.append(f'<polygon points="{points}"/>')
    lines += ['</g>', '</svg>']
    (OUT/'uv'/f'{obj.name}.svg').write_text('\n'.join(lines), encoding='utf-8')


for obj, record in zip(objects, records):
    mesh = obj.data
    mesh.calc_loop_triangles()
    assert all(p.area > 1e-10 for p in mesh.polygons), obj.name + ': degenerate faces'
    assert all(math.isfinite(x) for v in mesh.vertices for x in v.co), obj.name
    assert all(-1e-5 <= x <= 1.00001 for uv in mesh.uv_layers.active.data for x in uv.uv), obj.name
    edges = Counter(tuple(sorted((p.vertices[i], p.vertices[(i+1)%len(p.vertices)])))
                    for p in mesh.polygons for i in range(len(p.vertices)))
    boundary = sum(v == 1 for v in edges.values())
    assert max(edges.values()) <= 2, obj.name + ': nonmanifold edge'
    if 'shard' in obj.name:
        assert boundary == 0, obj.name + ': shard is not closed'
    record.update(vertices=len(mesh.vertices), triangles=len(mesh.loop_triangles),
                  boundary_edges=boundary, glb='res://art/vfx/templates/'+obj.name+'.glb')
    uv_svg(obj)
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.context.view_layer.update()
    record['dimensions_blender_m'] = list(obj.dimensions)
    bpy.ops.export_scene.gltf(filepath=str(EXPORT/(obj.name+'.glb')), export_format='GLB',
                              use_selection=True, export_yup=True, export_texcoords=True,
                              export_normals=True, export_animations=False, export_extras=True)
    record['file_bytes'] = (EXPORT/(obj.name+'.glb')).stat().st_size

# Editable UV checker is packed into the blend, not exported into runtime models.
checker = bpy.data.images.new('VFX_UV_Checker', width=1024, height=1024)
checker.generated_type = 'COLOR_GRID'
checker.pack()
checkmat = material('M_UV_Checker_Preview_Only', (1,1,1))
checkmat.use_fake_user = True
tex = checkmat.node_tree.nodes.new('ShaderNodeTexImage')
tex.image = checker
bsdf = next(n for n in checkmat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
checkmat.node_tree.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])

# Arrange assets only after exports; individual files remain centered at origin.
for idx, obj in enumerate(objects):
    obj.location = ((idx%5-2)*3.5, (1-idx//5)*4.0, 0)
    textcurve = bpy.data.curves.new('Label_'+obj.name, 'FONT')
    textcurve.body = f'{idx+1:02d}  {obj.name.removeprefix("fx_")}\n{records[idx]["triangles"]} triangles'
    textcurve.size = .20
    textcurve.align_x = 'CENTER'
    label = bpy.data.objects.new('Label_'+obj.name, textcurve)
    display.objects.link(label)
    label.location = obj.location + Vector((0,-1.65,.015))

camera_data = bpy.data.cameras.new('Preview_Camera')
camera = bpy.data.objects.new('Preview_Camera', camera_data)
display.objects.link(camera)
camera.location = (0,-8,30)
camera.rotation_euler = (Vector((0,2,0.15))-camera.location).to_track_quat('-Z','Y').to_euler()
camera_data.type = 'ORTHO'
camera_data.ortho_scale = 19.0
scene.camera = camera
scene.render.engine = 'BLENDER_WORKBENCH'
scene.render.resolution_x = 2000
scene.render.resolution_y = 1200
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
shading = scene.display.shading
shading.light = 'STUDIO'
shading.color_type = 'MATERIAL'
shading.show_shadows = True
shading.show_cavity = True
shading.cavity_type = 'BOTH'
shading.background_type = 'WORLD'
scene.world.color = (.025,.035,.05)
scene.view_settings.view_transform = 'Standard'
bpy.ops.object.select_all(action='DESELECT')
objects[0].select_set(True)
bpy.context.view_layer.objects.active = objects[0]
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == 'VIEW_3D':
            area.spaces.active.region_3d.view_distance = 22
            area.spaces.active.region_3d.view_location = (0,2,0)
            area.spaces.active.region_3d.view_rotation = camera.rotation_euler.to_quaternion()
            area.spaces.active.shading.color_type = 'MATERIAL'
scene.render.filepath = str(OUT/'templates_overview.png')
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'vfx_templates.blend'))
bpy.ops.render.render(write_still=True)

# Round-trip GLBs into separate clean scenes and check exported mesh contracts.
for record in records:
    check_scene = bpy.data.scenes.new('Validate_'+record['name'])
    bpy.context.window.scene = check_scene
    bpy.ops.import_scene.gltf(filepath=str(EXPORT/(record['name']+'.glb')))
    imported = [o for o in check_scene.objects if o.type == 'MESH']
    assert len(imported) == 1, record['name']
    obj = imported[0]
    obj.data.calc_loop_triangles()
    assert len(obj.data.loop_triangles) == record['triangles'], record['name']
    assert len(obj.data.uv_layers) > 0, record['name']
    assert obj.matrix_world.translation.length < 1e-5, record['name']
    assert all(abs(a-b)<1e-4 for a,b in zip(obj.dimensions, record['dimensions_blender_m'])), record['name']
    record['roundtrip_validation'] = 'PASS: triangle count, UV, dimensions, zero origin'
manifest = {'blender_version': bpy.app.version_string, 'units': 'meters',
            'axis': 'Blender Z up -> glTF/Godot Y up; (x,y,z) -> (x,z,-y)',
            'asset_count': len(records), 'total_triangles': sum(r['triangles'] for r in records),
            'assets': records}
(OUT/'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
print('VFX_TEMPLATES_OK', json.dumps({'assets':len(records),'triangles':manifest['total_triangles']}))
