extends SceneTree
## 性能复测工具（可重复使用）：
##   & '<Godot>' --path '<项目>' --script res://tools/perf_probe.gd -- [scene]
## 关 VSync 跑 300 帧，输出构建耗时 / 规模 / draw call / 三角形 / 显存 / 帧时间。

var _frames := 0
var _level: Node = null
var _samples: Array[float] = []
var _scene := "res://scenes/level_1.tscn"
var _build_ms := 0.0
var _audio_ms := 0.0
var _t_start := 0
var _build_done_reported := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_scene = args[0]
	print("=== PERF PROBE ", _scene, " ===")
	# 音频资源加载耗时（烘焙后的 .res 数量与耗时）
	var t0 := Time.get_ticks_usec()
	var n := 0
	for f in DirAccess.get_files_at("res://audio"):
		if f.ends_with(".res"):
			load("res://audio/" + f)
			n += 1
	_audio_ms = (Time.get_ticks_usec() - t0) / 1000.0
	print("AUDIO files=%d load_ms=%.1f" % [n, _audio_ms])


func _process(delta: float) -> bool:
	_frames += 1

	if _frames == 1:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
		_t_start = Time.get_ticks_usec()
		var t0 := Time.get_ticks_usec()
		_level = (load(_scene) as PackedScene).instantiate()
		root.add_child(_level)
		_build_ms = (Time.get_ticks_usec() - t0) / 1000.0
		print("BUILD add_child_ms=%.1f (含 _ready 的同步部分)" % _build_ms)
		return false

	if _frames > 1 and not _build_done_reported and _level != null and _level.get("build_done"):
		_build_done_reported = true
		print("SCENE_READY_MS=%.1f frames=%d（从实例化到可操作，含分帧构建+预热）" % [
			(Time.get_ticks_usec() - _t_start) / 1000.0, _frames])

	if _frames == 90:
		_dump("settled")

	if _frames > 120:
		_samples.append(delta)

	if _frames == 420:
		var arr := _samples.duplicate()
		arr.sort()
		var n := arr.size()
		var sum := 0.0
		for v in arr: sum += v
		print("FRAME avg_ms=%.2f fps=%.1f p50=%.2f p95=%.2f max=%.2f" % [
			sum / n * 1000.0, n / sum, arr[int(n * 0.5)] * 1000.0,
			arr[int(n * 0.95)] * 1000.0, arr[n - 1] * 1000.0])
		print("=== PERF END ===")
		return true
	return false


func _dump(tag: String) -> void:
	var c := {}
	var lights := 0
	var meshes := 0
	var parts := 0
	var labels := 0
	var mats := {}
	var stack: Array[Node] = [root]
	var nodes := 0
	while stack.size() > 0:
		var nd: Node = stack.pop_back()
		nodes += 1
		if nd is Light3D:
			lights += 1
		if nd is MeshInstance3D:
			meshes += 1
			var m: MeshInstance3D = nd
			if m.material_override:
				mats[m.material_override.get_instance_id()] = true
		if nd is GPUParticles3D:
			parts += 1
		if nd is Label3D:
			labels += 1
		stack.append_array(nd.get_children())
	print("[%s] nodes=%d meshes=%d lights=%d particles=%d label3d=%d uniq_override_mats=%d | tex=%s | draw=%d prim=%d vram=%.0fMB" % [
		tag, nodes, meshes, lights, parts, labels, mats.size(),
		str(root.get_texture().get_size()),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])
