
import bpy, sys, json
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=r"E:\godot_game_by_fable\001\art\models\nezha_opt.glb")

rep = {"objects": [], "materials": []}
for ob in bpy.data.objects:
    d = {"name": ob.name, "type": ob.type}
    if ob.type == 'MESH':
        me = ob.data
        d["tris"] = sum(len(p.vertices) - 2 for p in me.polygons)
        d["verts"] = len(me.vertices)
        d["uv_layers"] = [u.name for u in me.uv_layers]
        d["color_attrs"] = [(c.name, c.domain, c.data_type) for c in me.color_attributes]
        d["materials"] = [ms.material.name if ms.material else None for ms in ob.material_slots]
        d["vgroups"] = [g.name for g in ob.vertex_groups]
        d["modifiers"] = [m.type for m in ob.modifiers]
        d["parent"] = ob.parent.name if ob.parent else None
        d["has_custom_normals"] = me.has_custom_normals
    if ob.type == 'ARMATURE':
        d["bones"] = len(ob.data.bones)
    rep["objects"].append(d)

for m in bpy.data.materials:
    rep["materials"].append({"name": m.name, "use_nodes": m.use_nodes,
                             "nodes": [n.type for n in m.node_tree.nodes] if m.use_nodes else []})

rep["blender"] = bpy.app.version_string
print("PROBE_JSON_START")
print(json.dumps(rep, indent=1))
print("PROBE_JSON_END")
