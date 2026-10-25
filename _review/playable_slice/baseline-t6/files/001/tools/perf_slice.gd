extends SceneTree
## 交付性能测量（第一章出生点 / Boss 战场）：
##   & '<Godot>' --path '<项目>' --script res://tools/perf_slice.gd -- [scene] [x] [label]
## x < -9000 表示不传送（出生点）；否则第 120 帧传送并把镜头贴到该处，150 帧起触发 Boss。
## 关 VSync、不限帧，采样 180~480 帧，输出 CPU 帧时间分布 / 绘制调用 / 三角形 / 显存。

var _scene := "res://scenes/level_1.tscn"
var _x := -9999.0
var _label := "spawn"
var _frames := 0
var _level: Node = null
var _samples: Array[float] = []
var _build_ms := 0.0
var _t0 := 0
var _reported := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: _scene = args[0]
	if args.size() > 1: _x = float(args[1])
	if args.size() > 2: _label = args[2]
	print("=== PERF_SLICE ", _label, " ", _scene, " x=", _x, " ===")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var t := Time.get_ticks_usec()
	_level = (load(_scene) as PackedScene).instantiate()
	root.add_child(_level)
	_build_ms = (Time.get_ticks_usec() - t) / 1000.0
	_t0 = t
	print("BUILD add_child_ms=%.1f" % _build_ms)


func _process(delta: float) -> bool:
	_frames += 1
	if _frames == 120 and _x > -9000.0 and _level.get("player") != null:
		var p: Node3D = _level.get("player")
		p.set("hp", 1000.0)
		p.global_position = Vector3(_x, 7.0, 0.0)
		if p is CharacterBody3D:
			(p as CharacterBody3D).velocity = Vector3.ZERO
		var c = _level.get("cam")
		if c != null:
			c.call("snap_to_target")
		print("TELEPORT x=%.1f" % _x)
	if _frames == 150 and _x > -9000.0:
		_level.call("_start_boss")
	if _frames > 180 and _frames <= 480:
		_samples.append(delta)
	if _frames == 480:
		_report()
		return true
	return false


func _report() -> void:
	var arr := _samples.duplicate()
	arr.sort()
	var n := arr.size()
	var sum := 0.0
	for v in arr: sum += v
	print("FRAME[%s] avg_ms=%.2f fps=%.1f p50=%.2f p95=%.2f max=%.2f samples=%d" % [
		_label, sum / n * 1000.0, n / sum, arr[int(n * 0.5)] * 1000.0,
		arr[int(n * 0.95)] * 1000.0, arr[n - 1] * 1000.0, n])
	print("SCENE_READY_MS=%.1f" % ((Time.get_ticks_usec() - _t0) / 1000.0))
	print("draw=%d prim=%d vram=%.0fMB nodes=%d" % [
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		count_nodes(root)])
	print("=== PERF_SLICE END ===")


func count_nodes(n: Node) -> int:
	var c := 1
	for ch in n.get_children(): c += count_nodes(ch)
	return c
