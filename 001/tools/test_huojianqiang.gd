extends SceneTree
## Actual imported weapon geometry and rigid hand attachment across every clip.

var failed := false
var checks: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, label: String) -> void:
	if ok:
		checks.append(label)
		print("PASS ", label)
	else:
		failed = true
		push_error("HUOJIANQIANG_FAIL " + label)


func _run() -> void:
	var actor = load("res://scripts/player.gd").new()
	root.add_child(actor)
	actor.set_physics_process(false)
	var visual: Node3D = actor.spear.get_node("HuojianqiangModel")
	var meshes := visual.find_children("*", "MeshInstance3D", true, false)
	check(meshes.size() == 1, "supplied weapon mesh replaces procedural spear")
	var mesh: MeshInstance3D = meshes[0]
	var bounds: AABB = actor.spear.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
	check(absf(bounds.end.y - 1.27) < .003 and absf(bounds.size.y - 1.799) < .01, "weapon size and blade reach calibrated")
	check(bounds.has_point(Vector3(0, -.25, 0)), "hand socket lies inside handle bounds")
	var triangles := 0
	for surface in mesh.mesh.get_surface_count():
		var arrays := mesh.mesh.surface_get_arrays(surface)
		triangles += arrays[Mesh.ARRAY_INDEX].size() / 3
	check(triangles > 40000 and triangles <= 45010, "game mesh within 45k triangle budget")
	var material := mesh.get_active_material(0) as StandardMaterial3D
	check(material != null and material.albedo_texture != null and material.normal_texture != null
		and material.roughness_texture != null and material.metallic_texture != null, "original PBR textures retained")
	check(actor.spear.get_child_count() == 2 and actor.spear.get_child(1) is GPUParticles3D, "original tip flame retained without duplicate old mesh")
	var max_error := 0.0
	var samples := 0
	for clip: String in actor.NezhaMotion.CLIPS:
		var valid := true
		var axis_valid := true
		for facing in [0.0, PI]:
			actor.gfx.rotation.y = facing
			actor._motion.current = clip
			actor.skel.reset_bone_poses()
			actor._motion.player.play(clip, 0.0)
			for index in 10:
				actor._motion.player.seek(actor._motion.player.get_animation(clip).length * index / 9.0, true)
				actor._update_spear_follow()
				var hand: Transform3D = actor.skel.global_transform * actor.skel.get_bone_global_pose(actor.skel.find_bone("hand.r"))
				var expected: Vector3 = hand * actor.NezhaMotion.GRIP
				var actual: Vector3 = actor.spear.global_transform * Vector3(0, -.25, 0)
				var error := actual.distance_to(expected)
				max_error = maxf(max_error, error)
				valid = valid and error < .002 and actor.spear.global_transform.is_finite()
				var axis: Vector3 = (hand.basis * actor._motion.weapon_axis()).normalized()
				axis_valid = axis_valid and actor.spear.global_basis.y.normalized().dot(axis) > .999
				samples += 1
		check(valid, "rigid grip both facings " + clip)
		check(axis_valid, "blade axis both facings " + clip)
	var report := {"passed": not failed, "checks": checks.size(), "pose_samples": samples,
		"max_grip_error_m": max_error, "triangles": triangles}
	var file := FileAccess.open("E:/godot_game_by_fable/_review/huojianqiang/game_validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	print("HUOJIANQIANG_VALIDATION ", JSON.stringify(report))
	actor.queue_free()
	await process_frame
	quit(1 if failed else 0)
