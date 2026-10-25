extends SceneTree
## Chapter-local scenery and unchanged gameplay-surface regression checks.

var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
	else:
		print("PASS ", message)


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var level := (load("res://scenes/level_1.tscn") as PackedScene).instantiate()
	root.add_child(level)
	for i in 180:
		await process_frame
		if level.get("build_done"):
			break
	check(level.get("build_done") == true, "chapter finishes construction")
	var scenery := level.get_node_or_null("HybridRuins")
	check(scenery != null, "chapter has dedicated HybridRuins visual root")
	if scenery != null:
		for layer in ["NearRuins", "MidRuins", "FarPalace"]:
			check(scenery.get_node_or_null(layer) != null, "separate " + layer + " depth layer")
		check(scenery.find_children("*", "CollisionObject3D", true, false).is_empty(),
			"scenery adds no physics bodies or hazards")
		check(get_nodes_in_group("ch1_ruin_column").size() >= 12, "real colonnade spans the chapter")
		var rails := get_nodes_in_group("ch1_ruin_rail")
		check(not rails.is_empty(), "real rail modules are present")
		for rail in rails:
			var box: AABB = scenery.model_aabb(rail)
			check(box.size.x > box.size.z * 2.0, "rail long axis follows horizontal route")
	var has_full_reference := false
	for mi in level.find_children("*", "MeshInstance3D", true, false):
		var mat: Material = mi.get_active_material(0) if mi.mesh != null else null
		if mat is BaseMaterial3D and mat.albedo_texture != null:
			has_full_reference = has_full_reference or mat.albedo_texture.resource_path.ends_with("ch1_corridor.png")
	check(not has_full_reference, "no complete reference image used as world backdrop")
	await physics_frame
	var space := root.world_3d.direct_space_state
	for surface in [[4.0, 0.0], [24.0, 0.5], [44.0, 1.0], [72.0, 6.0],
			[84.0, 6.0], [104.0, 6.0], [110.0, 6.0], [144.0, 2.0],
			[10.0, 4.4], [33.0, 1.8], [60.0, 4.2], [127.5, 3.2]]:
		var query := PhysicsRayQueryParameters3D.create(
			Vector3(surface[0], surface[1] + 0.3, 0),
			Vector3(surface[0], surface[1] - 0.4, 0), 1)
		var hit := space.intersect_ray(query)
		check(not hit.is_empty() and absf(hit.position.y - surface[1]) < 0.03,
			"original walk surface at x=%s y=%s" % surface)
	var gap := PhysicsRayQueryParameters3D.create(Vector3(17.5, 2.0, 0), Vector3(17.5, -4.0, 0), 1)
	check(space.intersect_ray(gap).is_empty(), "first jump gap remains open")
	check(level.get("_checkpoints").size() == 5, "five original checkpoints retained")
	check(level.get("boss") != null and level.get("boss").hp == 480,
		"original Boss and health retained")
	print("CH1_HYBRID failures=", failures)
	level.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
