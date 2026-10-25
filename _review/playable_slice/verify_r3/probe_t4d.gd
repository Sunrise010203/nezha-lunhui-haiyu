extends SceneTree
## t4 attempt3: four-chapter tide/slow availability; Boss/death covered by probe_t4b.
var checks := 0
var fails := 0
var game: Node
var level: Node
var player: Node

func check(ok: bool, msg: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + msg)
	if not ok:
		fails += 1
		push_error("T4_FAIL " + msg)

func wait_process(n: int) -> void:
	for i in n:
		await process_frame

func wait_build(l: Node) -> void:
	for i in 500:
		await process_frame
		if l.get("build_done"):
			return

func load_chapter(path: String, id: String) -> void:
	if level != null and is_instance_valid(level):
		current_scene = null
		level.queue_free()
		await wait_process(4)
	game.start_campaign()
	game.campaign_chapter = id
	level = (load(path) as PackedScene).instantiate()
	root.add_child(level)
	current_scene = level
	await wait_build(level)
	player = level.get("player")
	await wait_process(20)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	print("=== T4 PROBE D ===")
	game = root.get_node_or_null("Game")
	check(game != null, "Game autoload")
	var chapters := [
		{"path": "res://scenes/level_1.tscn", "id": "ch1"},
		{"path": "res://scenes/level_2.tscn", "id": "ch2"},
		{"path": "res://scenes/level_3.tscn", "id": "ch3"},
		{"path": "res://scenes/level_4.tscn", "id": "ch4"},
	]
	for c in chapters:
		await load_chapter(c["path"], c["id"])
		var cid: String = c["id"]
		check(player != null, "%s: player loaded" % cid)
		var want_tide := cid == "ch4"
		check(bool(game.tide_unlocked) == want_tide, "%s: tide unlock=%s (expected %s)" % [cid, str(game.tide_unlocked), str(want_tide)])
		# 定潮输入只在第四章生效；前三章不得进入架/引状态
		Input.action_press("tide")
		await wait_process(12)
		var guarding: bool = player.call("is_guarding") if player.has_method("is_guarding") else false
		Input.action_release("tide")
		await wait_process(2)
		check(guarding == want_tide, "%s: tide guard=%s (expected %s)" % [cid, str(guarding), str(want_tide)])
		# 减速入口通用，且值/时长可写入；复活清理由 test_gameplay_states 覆盖
		check(player.has_method("apply_slow"), "%s: player apply_slow exists" % cid)
		player.call("apply_slow", 0.5, 2.0)
		check(is_equal_approx(float(player.get("_slow_amount")), 0.5), "%s: slow amount applied" % cid)
		check(float(player.get("_slow_t")) > 1.9, "%s: slow duration applied" % cid)
		player.set("_slow_amount", 0.0)
		player.set("_slow_t", 0.0)
	print("T4_PROBE_D checks=%d fails=%d" % [checks, fails])
	quit(1 if fails else 0)
