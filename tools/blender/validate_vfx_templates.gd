extends SceneTree
## Run in a tiny isolated project; GLTFDocument imports actual delivery files.

func _init() -> void:
	call_deferred("verify")

func verify() -> void:
	var args := OS.get_cmdline_user_args()
	var base: String = args[0]
	var manifest_path := base.path_join("art_source/vfx_templates/manifest.json")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	var results: Array = []
	var failed := false
	for record: Dictionary in manifest.assets:
		var path := base.path_join("001/art/vfx/templates/" + str(record.name) + ".glb")
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		var error := document.append_from_file(path, state)
		if error != OK:
			results.append({"name": record.name, "error": error})
			failed = true
			continue
		var model := document.generate_scene(state)
		root.add_child(model)
		var meshes := model.find_children("*", "MeshInstance3D", true, false)
		var triangles := 0
		var valid := meshes.size() == 1
		for node: MeshInstance3D in meshes:
			valid = valid and node.global_position.length() < 0.0001
			for surface in node.mesh.get_surface_count():
				var arrays := node.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				triangles += int(indices.size() / 3) if not indices.is_empty() else int(vertices.size() / 3)
				valid = valid and vertices.size() == normals.size() and vertices.size() == uv.size()
				for normal: Vector3 in normals:
					valid = valid and absf(normal.length() - 1.0) < 0.01
				for coord: Vector2 in uv:
					valid = valid and coord.x >= -0.0001 and coord.x <= 1.0001 and coord.y >= -0.0001 and coord.y <= 1.0001
			var size: Vector3 = (node.global_transform * node.get_aabb()).size
			var source: Array = record.dimensions_blender_m
			var expected := Vector3(source[0], source[2], source[1])
			valid = valid and size.distance_to(expected) < 0.001
		valid = valid and triangles == int(record.triangles)
		results.append({"name": record.name, "pass": valid, "triangles": triangles})
		failed = failed or not valid
		model.free()
	var report := {"engine": Engine.get_version_info().string, "pass": not failed, "assets": results,
		"checks": "GLTFDocument import; mesh count; triangles; UV range; unit normals; zero origin; Y-up dimensions"}
	var file := FileAccess.open(base.path_join("art_source/vfx_templates/godot_validation.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print(JSON.stringify(report))
	quit(1 if failed else 0)
