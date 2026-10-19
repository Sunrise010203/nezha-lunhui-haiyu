extends SceneTree
## 截图工具：真实渲染器下加载关卡、等构建完成、可选传送到指定 x / 触发 Boss，然后存 PNG。
## 用法：
##   & '<Godot>' --path '<项目>' --script res://tools/capture.gd -- \
##       res://scenes/level_1.tscn "E:\...\shot.png" [x] [frames] [mode] [shots] [interval]
##   mode: normal | boss
##   shots/interval：连拍张数与间隔帧数（默认 1 张）
## 注意：必须真实渲染器（不要 --headless），否则 get_image() 拿不到画面。

var _scene := "res://scenes/level_1.tscn"
var _out := "user://shot.png"
var _x := -9999.0
var _wait := 240
var _mode := "normal"
var _shots := 1
var _interval := 20
var _frames := 0
var _level: Node = null
var _taken := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: _scene = args[0]
	if args.size() > 1: _out = args[1]
	if args.size() > 2: _x = float(args[2])
	if args.size() > 3: _wait = int(args[3])
	if args.size() > 4: _mode = args[4]
	if args.size() > 5: _shots = maxi(int(args[5]), 1)
	if args.size() > 6: _interval = maxi(int(args[6]), 1)
	print("[capture] scene=", _scene, " x=", _x, " wait=", _wait, " mode=", _mode,
		" shots=", _shots, " interval=", _interval)
	# 模式：campaign = 闯关初始（只有 Q，E/V 上锁）；select = 全技能
	var g := root.get_node_or_null("Game")
	if g:
		if _mode.contains("campaign"):
			g.call("start_campaign")
		elif _mode.contains("select"):
			g.call("start_select_mode")
	_level = (load(_scene) as PackedScene).instantiate()
	root.add_child(_level)


func _process(_delta: float) -> bool:
	_frames += 1

	# 第 90 帧：分帧构建应已完成，此时再传送/触发 Boss，避免踩着未建好的地形
	if _frames == 90:
		print("[capture] build_done=", _level.get("build_done"))
		if _mode.begins_with("boss"):
			_level.call("_start_boss")
		if _x > -9000.0 and _level.get("player") != null:
			var p: Node3D = _level.get("player")
			# 从上方落下：直接改 x 会卡进平台，导致坠渊重生
			p.global_position = Vector3(_x, 7.0, 0.0)
			if p is CharacterBody3D:
				(p as CharacterBody3D).velocity = Vector3.ZERO
			var c = _level.get("cam")
			if c != null:
				# closeup：镜头拉近，用于检查角色细节（飘带/手持武器/脚下圈）
				if _mode.contains("closeup"):
					c.call("set_framing", -5.0, 0.0)
				c.call("snap_to_target")
				c.call("snap_to_target")
		return false

	# 奔跑模式：截图前 8 帧按下右移（约 0.13 秒），
	# 足够进入"奔跑"姿态分支，又不会跑出镜头或掉下平台。
	if _mode.contains("run") and _frames == _wait - 8:
		Input.action_press("move_right")
		print("[capture] hold move_right for run pose")

	# 调试模式：强制生成一枚统一预警环，用来目检 Game.style_warning_ring
	if _mode.contains("warn") and _frames == 120:
		var pl = _level.get("player")
		if pl != null:
			var t := TorusMesh.new()
			t.inner_radius = 1.6
			t.outer_radius = 1.9
			t.ring_segments = 48
			t.rings = 8
			var mi := MeshInstance3D.new()
			mi.mesh = t
			mi.position = pl.global_position + Vector3(1.6, 0.12, 0)
			mi.scale = Vector3(1, 0.15, 1)
			_level.add_child(mi)
			var g = root.get_node_or_null("Game")
			if g != null:
				g.call("style_warning_ring", mi, 1.9)
			print("[capture] debug warning ring spawned")
		return false

	# 调试模式：隐藏脚下拆出来的 nezha_ring，用来分辨"脚踝处的环"到底属于
	# 圈对象还是还留在主体网格上（mode 里带 hidring 就会隐藏）
	if _mode.contains("hidring") and _frames == 120 and _level.get("player") != null:
		var p5 = _level.get("player")
		var fr = p5.get("_foot_ring")
		if fr != null:
			print("[capture] ring node=", fr.name, " pos=", (fr as Node3D).global_position,
				" visible=", (fr as Node3D).visible)
			if fr is MeshInstance3D:
				print("[capture] ring aabb=", (fr as MeshInstance3D).get_aabb())
			(fr as Node3D).visible = false
			print("[capture] foot ring hidden")
		else:
			print("[capture] WARN no _foot_ring")

	# 抓索模式：传送后让玩家真的甩出混天绫（F），用来截"摆荡中"的画面
	if _mode.contains("swing") and _frames == 130 and _level.get("player") != null:
		_level.get("player").call("_do_grapple")
		print("[capture] swing fired: act=", _level.get("player").get("act"))

	# 引力井模式：强制 Boss 进入"海眼引力"，截机制说明画面
	if _mode.contains("well") and _frames == 150:
		var b = _level.get("boss")
		if b != null:
			b.set("state", "tele")
			b.set("_cast_kind", "well")
			b.set("_cast_core", 0)
			b.set("_tele_time", 0.01)
			b.set("state_t", 0.0)
			print("[capture] boss forced to gravity well")

	# 风火轮模式：解锁 V 并在传送后释放，截技能特效
	if _mode.contains("wheel") and _frames == 140 and _level.get("player") != null:
		var g2 := root.get_node_or_null("Game")
		if g2:
			g2.get("skills")["V"] = true
		var p2 = _level.get("player")
		p2.set("energy", 100.0)
		p2.call("_cast_wheel")
		print("[capture] wheel fired: wheel_t=", p2.get("wheel_t"))

	# 乾坤圈蓄力模式：解锁 E 并开始蓄力（人物定格）
	if _mode.contains("ringcharge") and _frames == 140 and _level.get("player") != null:
		var g3 := root.get_node_or_null("Game")
		if g3:
			g3.get("skills")["E"] = true
		var p3 = _level.get("player")
		p3.set("energy", 100.0)
		p3.call("_start_ring_charge")
		print("[capture] ring charging")

	# 死亡面板模式：把玩家打死，截死亡/重开界面
	if _mode.contains("death") and _frames == 140 and _level.get("player") != null:
		var p4 = _level.get("player")
		p4.set("hp", 1.0)
		p4.call("take_damage", 9999.0, 0.0)
		print("[capture] player killed for death overlay")

	var start := _wait
	var end := _wait + (_shots - 1) * _interval
	if _frames >= start and _frames <= end and (_frames - start) % _interval == 0:
		_taken += 1
		var path := _out
		if _shots > 1:
			path = _out.replace(".png", "_%02d.png" % _taken)
		var img := root.get_texture().get_image()
		var err := img.save_png(path)
		var b = _level.get("boss")
		var pl = _level.get("player")
		print("[capture] saved=%s err=%d boss_state=%s boss_pos=%s boss_hp=%s" % [
			path, err, (b.state if b != null else "-"),
			str(b.global_position if b != null else Vector3.ZERO),
			str(b.hp if b != null else -1)])
		if _taken >= _shots:
			return true
	return false
