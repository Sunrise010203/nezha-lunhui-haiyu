extends Node
## 通用地形走查：按住右 + 连跳，验证"能不能走/跳过去"。
## 用法：
##   godot --headless --path 001 res://tools/probe_walk.tscn -- res://scenes/level_1.tscn 101:121

var _level: Node = null
var _p: Node = null


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var scene_path := args[0] if args.size() > 0 else "res://scenes/level_4.tscn"
	var spans: Array = []
	for i in range(1, args.size()):
		var parts: PackedStringArray = String(args[i]).split(":")
		if parts.size() == 2:
			spans.append([float(parts[0]), float(parts[1])])
	if spans.is_empty():
		spans = [[0.0, 20.0]]
	var scene: PackedScene = load(scene_path)
	_level = scene.instantiate()
	add_child(_level)
	await get_tree().create_timer(3.0).timeout
	_p = get_tree().get_first_node_in_group("player")
	print("=== WALK %s ===" % scene_path)
	for seg in spans:
		var from: float = seg[0]
		var to: float = seg[1]
		_p.global_position = Vector3(from, 12.0, 0.0)
		await get_tree().create_timer(1.3).timeout
		var x0: float = _p.global_position.x
		Input.action_press("move_right")
		var t := 0.0
		while t < 12.0:
			if _p.is_on_floor():
				Input.action_press("jump")
				await get_tree().create_timer(0.12).timeout
				Input.action_release("jump")
			await get_tree().create_timer(0.05).timeout
			t += 0.05
			if _p.global_position.x > to:
				break
		Input.action_release("move_right")
		var ok: bool = _p.global_position.x > to
		print("%s  %.1f -> %.1f  hp=%.0f  y=%.2f" % [
			"OK  " if ok else "FAIL", x0, _p.global_position.x, _p.hp,
			_p.global_position.y])
		if not ok:
			_p.global_position = Vector3(maxf(to - 1.0, x0), 12.0, 0.0)
			await get_tree().create_timer(0.6).timeout
	print("WALK DONE")
	get_tree().quit()
