extends SceneTree
## t4 独立验收探针 A：选关复活 / 暂停互斥 / 复活竞态 / 通关面板 / 闯关重开 / E 蓄力回灵
## 只读游戏状态，不改实现。运行：
##   Godot_console.exe --headless --path 001 --script <此文件绝对路径>

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

func pause_event() -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = "pause"
	ev.pressed = true
	return ev

func key_event(action_name: String) -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = action_name
	ev.pressed = true
	return ev

func wait_physics(n: int) -> void:
	for i in n:
		await physics_frame

func wait_process(n: int) -> void:
	for i in n:
		await process_frame

func wait_build(l: Node) -> void:
	for i in 400:
		await process_frame
		if l.get("build_done"):
			return

func collect_buttons(n: Node, out: Array) -> void:
	if n is Button:
		out.append(n)
	for c in n.get_children():
		collect_buttons(c, out)

func first_button() -> Button:
	var ov = hud.get("_overlay")
	if ov:
		var found: Array = hud.find_children("*", "Button", true, false)
		if found.size() > 0:
			return found[0]
		print("OVERLAY_DUMP children=", ov.get_child_count(), " class=", ov.get_class())
		_dump_tree(ov, 0)
	return null

func _dump_tree(n: Node, depth: int) -> void:
	print("  ".repeat(depth), n.get_class(), " name=", n.name)
	for c in n.get_children():
		_dump_tree(c, depth + 1)

func load_level(path: String) -> void:
	if level != null and is_instance_valid(level):
		level.queue_free()
		await wait_process(2)
	level = (load(path) as PackedScene).instantiate()
	root.add_child(level)
	current_scene = level
	await wait_build(level)
	player = level.get("player")
	hud = level.get("hud")
	await wait_physics(10)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	print("=== T4 PROBE A ===")
	game = root.get_node_or_null("Game")
	check(game != null, "Game autoload")
	if game == null:
		quit(1)
		return

	# ---------- 选关：死亡 -> 莲台重生按钮，能量保留、临时状态清理、锁释放
	game.start_select_mode()
	await load_level("res://scenes/level_1.tscn")
	check(player != null and hud != null, "select: player/hud")
	player.global_position = Vector3(4.0, 1.0, 0.0)
	player.velocity = Vector3.ZERO
	player.energy = 12.5
	player._energy_prev = 12.5
	player.wheel_t = 2.0
	player._ring_charging = true
	player._ring_charge = 0.4
	player.attack_buffer_t = 0.1
	player.jump_buffer = 0.1
	player.combo_cd = 0.2
	player.dash_t = 0.1
	player.dash_cd_t = 0.2
	player._slow_amount = 0.4
	player._slow_t = 2.0
	player.act = "hurt"
	player.act_t = 0.0
	player.dash_t = 0.0          # 冲刺无敌帧会吃掉这一击
	player.invuln = 0.0
	player.hp = 5.0
	print("HIT0 act=", player.act, " hp=", player.hp, " dash=", player.dash_t,
		" inv=", player.invuln, " energy=", player.energy)
	player.take_damage(20.0, 0.0)
	print("HIT0 after hp=", player.hp, " dead=", player.is_dead())
	check(player.is_dead(), "select: lethal damage kills")
	# 死亡等待 1.1 秒内 Esc 不得暂停
	hud._input(pause_event())
	check(paused == false and hud.get("_paused") == false,
		"select: Esc ignored during death delay")
	var t0 := Time.get_ticks_msec()
	while hud.overlay_kind() != "death" and Time.get_ticks_msec() - t0 < 4000:
		await process_frame
	check(hud.overlay_kind() == "death", "select: death panel shows")
	check(level.get("_death_pending") == true, "select: death_pending set")
	# 面板打开期间 Esc 不换面板
	var ov_ref = hud.get("_overlay")
	hud._input(pause_event())
	check(hud.overlay_kind() == "death" and hud.get("_overlay") == ov_ref,
		"select: Esc does not replace death panel")
	# 点第一个按钮（莲台重生）
	var btn := first_button()
	check(btn != null, "select: respawn button exists")
	if btn:
		btn.emit_signal("pressed")
	await wait_process(2)
	t0 = Time.get_ticks_msec()
	while level.get("_respawning") == true and Time.get_ticks_msec() - t0 < 4000:
		await process_frame
	check(player.hp == player.MAX_HP, "select: respawn full hp")
	check(player.act == "free", "select: respawn controllable")
	check(player.energy >= 12.5 and player.energy < 20.0,
		"select: energy kept (not refilled) %.2f" % player.energy)
	check(player.wheel_t == 0.0 and player._ring_charging == false
		and player.attack_buffer_t == 0.0 and player.jump_buffer == 0.0
		and player.combo_cd == 0.0 and player.dash_t == 0.0
		and player._slow_amount == 0.0, "select: temp state cleared")
	check(level.get("_respawning") == false, "select: respawning lock released")
	check(level.get("_death_pending") == false, "select: death_pending cleared")
	check(hud.overlay_kind() == "" and hud.get("_overlay") == null,
		"select: death panel cleared after respawn")

	# ---------- 死亡状态下再受击：take_damage 必须直接忽略（player.gd:1706）
	player.global_position = Vector3(4.0, 1.0, 0.0)
	player.invuln = 0.0
	player.hp = 1.0
	player.take_damage(5.0, 0.0)
	t0 = Time.get_ticks_msec()
	while hud.overlay_kind() != "death" and Time.get_ticks_msec() - t0 < 4000:
		await process_frame
	check(hud.overlay_kind() == "death", "dead-hit: death panel before respawn")
	var deaths_before: int = game.death_count
	player.invuln = 0.0
	player.take_damage(999.0, 0.0)
	check(game.death_count == deaths_before and player.is_dead(),
		"dead-hit: damage ignored while act=dead")
	btn = first_button()
	if btn:
		btn.emit_signal("pressed")
	await wait_process(2)
	t0 = Time.get_ticks_msec()
	while level.get("_respawning") == true and Time.get_ticks_msec() - t0 < 4000:
		await process_frame
	check(player.hp == player.MAX_HP and player.act == "free",
		"dead-hit: respawn completes after ignored hit")
	check(level.get("_respawning") == false, "dead-hit: respawning lock released")

	# ---------- 普通暂停 Esc 开关
	if hud.overlay_kind() != "":
		hud._clear_overlay()
		level.set("_death_pending", false)
		player.respawn(Vector3(4.0, 1.0, 0.0))
		await wait_process(5)
	hud._input(pause_event())
	check(paused == true and hud.get("_paused") == true
		and hud.overlay_kind() == "pause", "pause: Esc opens pause")
	hud._input(pause_event())
	check(paused == false and hud.get("_paused") == false
		and hud.overlay_kind() == "", "pause: Esc resumes")

	# ---------- 死亡面板下 Esc 不换面板（直接在 overlay 上验证）
	hud._clear_overlay()
	hud._show_overlay("命 陨 潮 渊", Color(0.9, 0.3, 0.3), "x", [], "death")
	ov_ref = hud.get("_overlay")
	hud._input(pause_event())
	check(hud.overlay_kind() == "death" and hud.get("_overlay") == ov_ref
		and paused == false, "death overlay: Esc no-op")
	# 清掉合成面板，避免阻挡后续真实 campaign_death（show_* 有 kind 守卫）
	hud._clear_overlay()
	await wait_process(2)

	# ---------- E 蓄力期间是否错误回灵（脱战 3s 后开始蓄力）
	player.respawn(Vector3(4.0, 1.0, 0.0))
	await wait_physics(5)
	player.energy = 10.0
	player._energy_prev = 10.0
	player.energy_idle = 3.0
	player._start_ring_charge()
	await wait_physics(30)
	var e_charge: float = player.energy
	print("ECHARGE act=", player.act, " energy=", e_charge, " idle=", player.energy_idle)
	check(player.act == "charge_ring", "charge: charging state entered")
	check(e_charge <= 10.05, "charge: no regen while charging (%.2f)" % e_charge)
	player._ring_charging = false
	player.act = "free"
	player._ring_charge = 0.0
	player.act_t = 0.0

	# ---------- 闯关死亡 -> 重新挑战本章：真实换场景、技能保留
	game.start_campaign()
	game.skills = {"Q": true, "E": true, "V": true}
	game.campaign_chapter = "ch1"
	player.invuln = 0.0
	player.hp = 5.0
	await wait_physics(2)
	player.take_damage(99.0, 0.0)
	t0 = Time.get_ticks_msec()
	while hud.overlay_kind() != "campaign_death" and Time.get_ticks_msec() - t0 < 4000:
		await process_frame
	check(hud.overlay_kind() == "campaign_death", "campaign: death panel")
	check(level.get("_death_pending") == true, "campaign: pending set")
	var old_level := level
	btn = first_button()
	check(btn != null, "campaign: restart button")
	if btn:
		btn.emit_signal("pressed")
	var reloaded := false
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 6000:
		await process_frame
		if current_scene != null and current_scene != old_level \
				and current_scene.get("player") != null:
			reloaded = true
			break
	check(reloaded, "campaign: scene reloaded")
	if reloaded:
		level = current_scene
		player = level.get("player")
		hud = level.get("hud")
		await wait_physics(10)
		check(game.campaign == true and game.campaign_chapter == "ch1",
			"campaign: chapter stays ch1")
		check(game.has_skill("E") and game.has_skill("V"),
			"campaign: unlocked skills kept")
		print("CAMPAIGN_RESTART hp=", player.hp, " energy=", player.energy)
		check(player.hp == player.MAX_HP and is_equal_approx(player.energy, 30.0),
			"campaign: new run full hp / starting energy 30")
		check(level.get("_restarting") == false, "campaign: new level restart lock clean")
		check(level.get("_death_pending") == false, "campaign: new level death lock clean")
		# ---------- 通关面板：任意键不推进（新 HUD，_ended 为 false）
		hud.show_victory()
		await wait_process(3)
		check(hud.overlay_kind() == "victory", "victory: panel shown")
		var vref = hud.get("_overlay")
		for a in ["attack", "ui_accept", "jump", "dash"]:
			hud._input(key_event(a))
		await wait_process(3)
		check(hud.overlay_kind() == "victory" and hud.get("_overlay") == vref
			and hud.get("_ended") == true, "victory: any key does not finish")
		hud.show_victory()
		await wait_process(2)
		check(hud.get("_overlay") == vref, "victory: repeat call idempotent")

	print("T4_PROBE_A checks=%d fails=%d" % [checks, fails])
	quit(0 if fails == 0 else 1)
