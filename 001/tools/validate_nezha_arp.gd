extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://art/models/nezha_arp.glb") as PackedScene
	assert(packed != null, "Cannot load rigged Nezha GLB")
	var model := packed.instantiate()
	root.add_child(model)
	var skeleton: Skeleton3D
	var meshes: Array[MeshInstance3D] = []
	for node in model.find_children("*", "", true, false):
		if node is Skeleton3D:
			skeleton = node
		elif node is MeshInstance3D:
			meshes.append(node)
	assert(skeleton != null, "Missing imported skeleton")
	assert(skeleton.get_bone_count() == 67, "Unexpected deform skeleton")
	assert(meshes.size() == 1, "Unexpected exported geometry")
	assert(meshes[0].skin != null, "Missing skin")
	assert(meshes[0].skin.get_bind_count() == 67, "Missing skin bindings")
	for name in ["root.x", "head.x", "hand.l", "hand.r", "thigh_stretch.l", "thigh_stretch.r", "leg_stretch.l", "leg_stretch.r"]:
		assert(skeleton.find_bone(name) >= 0, "Missing bone: " + name)
	for index in skeleton.get_bone_count():
		assert(skeleton.get_bone_global_rest(index).is_finite(), "Invalid bone rest")
	var material := meshes[0].mesh.surface_get_material(0) as StandardMaterial3D
	assert(material != null and material.albedo_texture != null, "Missing albedo")
	assert(material.albedo_texture.resource_path.ends_with("nezha_arp_Nezha_Albedo_Bright.png"), "Stale albedo texture")
	assert(material.albedo_texture.get_size() == Vector2(8192, 8192), "Unexpected albedo resolution")
	assert(not material.emission_enabled, "Unexpected self illumination")
	assert(material.normal_texture != null, "Missing normal map")
	print("NEZHA_ARP_IMPORT_PASS bones=%d meshes=%d binds=%d albedo=%s" % [
		skeleton.get_bone_count(), meshes.size(), meshes[0].skin.get_bind_count(),
		material.albedo_texture.get_size()])
	model.queue_free()
	await process_frame
	quit(0)
