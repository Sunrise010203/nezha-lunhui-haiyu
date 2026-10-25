extends SceneTree
## 交付性能测量（四章出生点 / Boss 战场 / 特效开关对比）：
##   & '<Godot>' --path '<项目>' --script res://tools/perf_slice.gd -- [scene] [x] [label] [flags]
## x < -9000 表示不传送（出生点）；否则第 120 帧传送并把镜头贴到该处，150 帧起触发 Boss。
## flags 逗号分隔：vfxoff = 关闭全部 GPUParticles3D/CPUParticles3D 发射，用于特效开关对比。
## 关 VSync、不限帧，采样 180~480 帧，输出 CPU 帧时间分布 / 绘制调用 / 三角形 / 显存。
## 注意：Godot 4.6 Performance 无 GPU 时间监视器，本工具不测 GPU 时间，也不据此推断瓶颈。
## 打包校验模式：
##   & '<Godot>' --headless --path '<项目>' --script res://tools/perf_slice.gd -- --packcheck <exe或pck>

var _scene := "res://scenes/level_1.tscn"
var _x := -9999.0
var _label := "spawn"
var _flags := ""
var _frames := 0
var _level: Node = null
var _samples: Array[float] = []
var _build_ms := 0.0
var _t0 := 0
var _vfx_disabled := 0
var _vfx_done := false
var _teleported := false
var _boss_started := false
var _t3 := false
var _t5 := false
var _t8 := false
var _t_start := 0
var _reported := false
var _level_ready_ms := 0.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and args[0] == "--packcheck":
		_packcheck(args[1] if args.size() > 1 else "")
		return
	if args.size() > 0: _scene = args[0]
	if args.size() > 1: _x = float(args[1])
	if args.size() > 2: _label = args[2]
	if args.size() > 3: _flags = args[3]
	print("=== PERF_SLICE ", _label, " ", _scene, " x=", _x, " flags=", _flags, " ===")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var t := Time.get_ticks_usec()
	_level = (load(_scene) as PackedScene).instantiate()
	root.add_child(_level)
	_build_ms = (Time.get_ticks_usec() - t) / 1000.0
	_t0 = t
	print("BUILD add_child_ms=%.1f" % _build_ms)


func _packcheck(path: String) -> void:
	## 从最终 exe / pck 直接加载内嵌资源包，证明资源可解析（而不是只看目录里有没有文件）。
	print("=== PACKCHECK ", path, " ===")
	var ok := ProjectSettings.load_resource_pack(path, false)
	print("PACK_LOAD ok=", ok)
	var probe := [
		"res://art/ref/ch1_palace_far.png",
		"res://art/ref/ch1_corridor.png",
		"res://art/backdrop.png",
		"res://scripts/ch1_ruins.gd",
		"res://scripts/player.gd",
		"res://scenes/level_1.tscn",
		"res://tools/capture.gd",
		"res://scenes/env_ch1_showcase.tscn",
		"res://art/models/glb_game",
	]
	for p in probe:
		var f := FileAccess.file_exists(p)
		var r := ResourceLoader.exists(p)
		print("PACK_PROBE %s file=%s res=%s" % [p, f, r])
	var tex = load("res://art/ref/ch1_palace_far.png")
	print("PACK_PALACE load=", tex)
	if tex is Texture2D:
		print("PACK_PALACE_SIZE ", (tex as Texture2D).get_size())
	var dir := DirAccess.open("res://art/ref")
	if dir:
		dir.list_dir_begin()
		var names: PackedStringArray = []
		var n := dir.get_next()
		while n != "":
			names.append(n)
			n = dir.get_next()
		dir.list_dir_end()
		print("PACK_ART_REF entries=", names.size(), " ", names)
	print("=== PACKCHECK END ===")
	quit()


func _process(delta: float) -> bool:
	_frames += 1
	if _t_start == 0:
		_t_start = Time.get_ticks_msec()
	var t := (Time.get_ticks_msec() - _t_start) / 1000.0
	if _level_ready_ms == 0.0 and _level != null:
		_level_ready_ms = t * 1000.0
	if t >= 1.0 and not _vfx_done and _flags.contains("vfxoff"):
		_vfx_done = true
		_vfx_disabled = _disable_vfx(root)
		print("VFX_OFF particles=", _vfx_disabled, " at=%.1fs" % t)
	if t >= 1.5 and not _teleported and _x > -9000.0 and _level.get("player") != null:
		_teleported = true
		var p: Node3D = _level.get("player")
		p.set("hp", 1000.0)
		p.global_position = Vector3(_x, 7.0, 0.0)
		if p is CharacterBody3D:
			(p as CharacterBody3D).velocity = Vector3.ZERO
		var c = _level.get("cam")
		if c != null:
			c.call("snap_to_target")
		print("TELEPORT x=%.1f at=%.1fs" % [_x, t])
	if t >= 2.0 and not _boss_started and _x > -9000.0:
		_boss_started = true
		_level.call("_start_boss")
		print("BOSS_START at=%.1fs" % t)
	if t >= 3.0 and not _t3:
		_t3 = true
		_print_boss("T3")
	if t >= 5.0 and not _t5:
		_t5 = true
		_print_boss("T5")
	if t >= 8.0 and not _t8:
		_t8 = true
		_print_boss("T8")
	if t >= 4.0 and t <= 10.0:
		_samples.append(delta)
	if t >= 10.5:
		_report()
		return true
	return false


func _print_boss(tag: String) -> void:
	var boss = _level.get("boss")
	if boss != null:
		print("BOSS_%s state=%s hp=%s started=%s" % [tag, boss.get("state"), boss.get("hp"), _level.get("boss_started")])
	print("LOAD_%s enemies=%d projectiles=%d vfx_particles=%d" % [
		tag, _alive_enemies(), _count_group("projectile"), _vfx_disabled])


func _disable_vfx(n: Node) -> int:
	var c := 0
	if n is GPUParticles3D:
		(n as GPUParticles3D).emitting = false
		(n as GPUParticles3D).visible = false
		c += 1
	elif n is CPUParticles3D:
		(n as CPUParticles3D).emitting = false
		(n as CPUParticles3D).visible = false
		c += 1
	for ch in n.get_children():
		c += _disable_vfx(ch)
	return c


func _alive_enemies() -> int:
	var c := 0
	for n in get_nodes_in_group("enemy"):
		if is_instance_valid(n) and not bool(n.get("dead")):
			c += 1
	return c


func _count_group(g: String) -> int:
	var c := 0
	for n in get_nodes_in_group(g):
		if is_instance_valid(n):
			c += 1
	return c


func _report() -> void:
	var arr := _samples.duplicate()
	arr.sort()
	var n := arr.size()
	var sum := 0.0
	for v in arr: sum += v
	var low_n := maxi(1, n / 100)
	var low_sum := 0.0
	for i in low_n: low_sum += arr[n - 1 - i]
	print("FRAME[%s] avg_ms=%.2f fps=%.1f p50=%.2f p95=%.2f p99=%.2f low1%%=%.2f max=%.2f samples=%d" % [
		_label, sum / n * 1000.0, n / sum, arr[int(n * 0.5)] * 1000.0,
		arr[int(n * 0.95)] * 1000.0, arr[int(n * 0.99)] * 1000.0, low_sum / low_n * 1000.0, arr[n - 1] * 1000.0, n])
	print("BUILD_MS=%.1f" % _level_ready_ms)
	print("SCENE_READY_MS=%.1f" % ((Time.get_ticks_usec() - _t0) / 1000.0))
	print("draw=%d prim=%d vram=%.0fMB nodes=%d" % [
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		count_nodes(root)])
	print("GPU_TIME_API=unavailable")
	print("=== PERF_SLICE END ===")


func count_nodes(n: Node) -> int:
	var c := 1
	for ch in n.get_children(): c += count_nodes(ch)
	return c
