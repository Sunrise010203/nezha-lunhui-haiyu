extends SceneTree

var failed := false
var report := {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for chapter in range(1, 5):
		var level = load("res://scenes/level_%d.tscn" % chapter).instantiate()
		root.add_child(level)
		var waited := 0
		while not level.build_done and waited < 600:
			await process_frame
			waited += 1
		var ok: bool = level.build_done and level.boss != null and level.boss.get("boss_motion") != null
		if not ok:
			failed = true
			push_error("BOSS_LEVEL_FAIL " + str(chapter))
		else:
			level.boss.reset_fight()
			ok = level.boss.boss_motion.current == "Idle"
			failed = failed or not ok
		var clips := {}
		var states := {}
		var finite := true
		if ok:
			level.player.set_physics_process(false)
			level.player.invuln = 1000.0
			level.player.global_position = Vector3(level.arena_min_x + 5.0, level.arena_ground_y + 1.0, 0.0)
			level._start_boss()
			for frame in 360:
				await physics_frame
				states[level.boss.state] = true
				clips[level.boss.boss_motion.current] = true
				if chapter == 3:
					for core in level.boss._cores:
						clips["core_" + core.motion.current] = true
				if frame % 30 == 0:
					var skeleton: Skeleton3D = level.boss.boss_motion.skeleton
					for bone in skeleton.get_bone_count():
						finite = finite and skeleton.get_bone_global_pose(bone).is_finite()
			ok = finite and states.size() > 1 and clips.size() > 1
			failed = failed or not ok
		report[str(chapter)] = {"built":level.build_done,"new_boss_rig":ok,"physics_frames":360,
			"finite_poses":finite,"observed_states":states.keys(),"observed_clips":clips.keys()}
		print("BOSS_LEVEL_CHECK ", chapter, " ", ok)
		level.queue_free()
		for i in 8:
			await process_frame
	var file := FileAccess.open("E:/godot_game_by_fable/_review/bosses_arp/level_tests.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"failed":failed,"chapters":report}, "  "))
	print("BOSS_LEVEL_TESTS FAILED=", failed)
	await create_timer(2.5, true, false, true).timeout
	quit(1 if failed else 0)
