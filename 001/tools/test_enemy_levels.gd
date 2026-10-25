extends SceneTree
## Check real chapter spawns, including arena factories, against the new rigs.

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
		if not level.build_done:
			failed = true
			push_error("Enemy chapter build timed out: " + str(chapter))
		var counts := {}
		for enemy in get_nodes_in_group("enemies"):
			var kind: String = enemy.get_script().resource_path.get_file().trim_prefix("enemy_").trim_suffix(".gd")
			if kind in ["crawler", "shooter", "divider", "guard", "turret", "wraith", "bomber", "spawnling"]:
				if enemy.enemy_motion == null:
					failed = true
					push_error("Missing live rig: " + kind)
				counts[kind] = counts.get(kind, 0) + 1
		# These use the same factory callbacks as arena and boss reinforcement spawns.
		for method: String in ["_spawn_crawler", "_spawn_shooter", "_spawn_divider", "_spawn_guard", "_spawn_turret", "_spawn_wraith", "_spawn_bomber", "_spawn_spawnling"]:
			var enemy = level.call(method, -30, 2) if method in ["_spawn_turret", "_spawn_bomber"] else level.call(method, -30, 2, -32, -28)
			if enemy.enemy_motion == null:
				failed = true
				push_error("Missing factory rig " + method)
			enemy.queue_free()
		report[str(chapter)] = {"built": level.build_done, "active_rigs": counts, "factories": 8}
		print("ENEMY_CHAPTER_PASS ", chapter, " ", counts)
		level.queue_free()
		for i in 4:
			await process_frame
	var file := FileAccess.open("E:/godot_game_by_fable/_review/enemies_arp/level_tests.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"failed": failed, "chapters": report}, "  "))
	print("ENEMY_LEVEL_TESTS FAILED=", failed)
	call_deferred("quit", 1 if failed else 0)
