extends SceneTree
## t4 独立验收探针 B：四章提示注册/真实按键完成/Boss 激活/死亡面板共享路径
## 运行：Godot_console.exe --headless --path 001 --script <绝对路径>

var checks := 0
var fails := 0
var game: Node
var level: Node
var player: Node
var hud: Node

func check(ok: bool, msg: String) -> void:
	checks += 1
	if ok:
		print("PASS ", msg)
	else:
		fails += 1
		print("FAIL ", msg)
		push_error("T4_FAIL " + msg)

func wait_process(n: int) -> void:
	for i in n:
		await process_frame

func wait_build(l: Node) -> void:
	for i in 500:
		await process_frame
		if l.get("build_done"):
			return

func load_chapter(path: String, chapter: String, title: String) -> void:
	if level != null and is_instance_valid(level):
		current_scene = null
		level.queue_free()
		await wait_process(4)
	game.start_campaign()
	game.campaign_chapter = chapter
	level = (load(path) as PackedScene).instantiate()
	root.add_child(level)
	current_scene = level
	await wait_build(level)
	player = level.get("player")
	hud = level.get("hud")
	await wait_process(30)

func first_visible_hint() -> Dictionary:
	var hs: Array = level.get("_hints")
	for h in hs:
		var lbl: Label3D = h["label"]
		if lbl and lbl.visible:
			return h
	return {}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	print("=== T4 PROBE B ===")
	game = root.get_node_or_null("Game")
	check(game != null, "Game autoload")
	var chapters := [
		{"path": "res://scenes/level_1.tscn", "id": "ch1", "title": "第一章", "hints": 9},
		{"path": "res://scenes/level_2.tscn", "id": "ch2", "title": "第二章", "hints": 5},
		{"path": "res://scenes/level_3.tscn", "id": "ch3", "title": "第三章", "hints": 5},
		{"path": "res://scenes/level_4.tscn", "id": "ch4", "title": "第四章", "hints": 9},
	]
	for c in chapters:
		await load_chapter(c["path"], c["id"], c["title"])
		var cid: String = c["id"]
		check(player != null and hud != null, "%s: player/hud loaded" % cid)
		var hs: Array = level.get("_hints")
		check(hs.size() == int(c["hints"]), "%s: hints registered %d" % [cid, hs.size()])
		# 把玩家放到第一条提示处，等淡入；确认提示由 _process 驱动显示
		if hs.size() > 0:
			var h0: Dictionary = hs[0]
			player.global_position = h0["pos"] + Vector3(0, 1.0, 0)
			player.velocity = Vector3.ZERO
			await wait_process(45)
			var lbl0: Label3D = h0["label"]
			check(lbl0.visible and lbl0.modulate.a > 0.5,
				"%s: hint visible near player (a=%.2f)" % [cid, lbl0.modulate.a])
			check(lbl0.text.length() > 3, "%s: hint text non-empty" % cid)
		# 真实按键完成：只接受该提示的 done_action，其他键无效
		if cid == "ch1":
			var hs2: Array = level.get("_hints")
			var jump_hint: Dictionary = {}
			for h in hs2:
				if str(h.get("done_action", "")) == "jump":
					jump_hint = h
					break
			check(not jump_hint.is_empty(), "ch1: jump hint exists")
			if not jump_hint.is_empty():
				player.global_position = jump_hint["pos"] + Vector3(0, 1.0, 0)
				player.velocity = Vector3.ZERO
				await wait_process(40)
				Input.action_press("attack")
				await wait_process(3)
				Input.action_release("attack")
				await wait_process(3)
				check(jump_hint["done"] == false, "ch1: wrong key does not complete hint")
				Input.action_press("jump")
				await wait_process(3)
				Input.action_release("jump")
				await wait_process(3)
				check(jump_hint["done"] == true, "ch1: matching key completes hint")
		else:
			# ch2-4 的提示无 done_action，任何按键都不应自动完成
			var h0b: Dictionary = hs[0]
			player.global_position = h0b["pos"] + Vector3(0, 1.0, 0)
			await wait_process(10)
			Input.action_press("attack")
			await wait_process(3)
			Input.action_release("attack")
			await wait_process(3)
			check(h0b["done"] == false, "%s: hint is non-blocking (never auto-done)" % cid)
		# Boss 启动冒烟：四章共用/覆写的 _start_boss 都不得报错
		check(level.has_method("_start_boss"), "%s: _start_boss exists" % cid)
		if level.has_method("_start_boss"):
			call_deferred("_dummy")
			level.call("_start_boss")
			await wait_process(120)
			check(level.get("boss_started") == true, "%s: boss started" % cid)
		# 死亡面板：四章共享 level_base -> HUD 闯关死亡路径
		player.invuln = 0.0
		player.hp = 1.0
		player.act = "free"
		player.dash_t = 0.0
		player.take_damage(999.0, 0.0)
		var t0 := Time.get_ticks_msec()
		while hud.overlay_kind() != "campaign_death" and Time.get_ticks_msec() - t0 < 4000:
			await process_frame
		check(hud.overlay_kind() == "campaign_death",
			"%s: campaign death panel" % cid)

	print("T4_PROBE_B checks=%d fails=%d" % [checks, fails])
	quit(0 if fails == 0 else 1)

func _dummy() -> void:
	pass
