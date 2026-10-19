extends SceneTree
## 一次性验收脚本：确认现成道具已实例化、可击碎物仍能正常掉落。
## 注意：这里刻意不直接引用 class_name（--script 模式下脚本编译早于 autoload），
## 改用脚本资源路径比较。

const BREAKABLE := "res://scripts/breakable.gd"
const PICKUP := "res://scripts/pickup.gd"

var _level: Node = null
var _frames := 0
var _scene := "res://scenes/level_1.tscn"
var _done := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_scene = args[0]
	_level = (load(_scene) as PackedScene).instantiate()
	root.add_child(_level)


func _has_script(n: Node, path: String) -> bool:
	var s: Script = n.get_script()
	return s != null and s.resource_path == path


func _collect(root_node: Node, path: String) -> Array[Node]:
	var out: Array[Node] = []
	var stack: Array[Node] = [root_node]
	while stack.size() > 0:
		var nd: Node = stack.pop_back()
		if _has_script(nd, path):
			out.append(nd)
		stack.append_array(nd.get_children())
	return out


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 120 or _done:
		return _done
	if not _level.get("build_done"):
		return false
	_done = true

	var prop_names := ["lantern", "chandelier", "statue", "rock_a", "rock_b",
		"rock_c", "urn_bronze", "urn_porcelain", "barrel", "pillar"]
	var counts := {}
	for n in prop_names:
		counts[n] = 0
	var stack: Array[Node] = [_level]
	while stack.size() > 0:
		var nd: Node = stack.pop_back()
		# 只统计"道具根节点"：父节点不是同名道具（避免把子网格重复计数）
		for n in prop_names:
			if String(nd.name).begins_with(n):
				var parent_name := String(nd.get_parent().name) if nd.get_parent() else ""
				if not parent_name.begins_with(n):
					counts[n] += 1
		stack.append_array(nd.get_children())

	var breakables := _collect(_level, BREAKABLE)
	var pickups_before := _collect(_level, PICKUP).size()
	var broke_ok := false
	if breakables.size() > 0:
		breakables[0].call("take_damage", 1.0, 0.0, false)
		broke_ok = _collect(_level, PICKUP).size() > pickups_before

	print("VERIFY scene=", _scene, " props=", counts,
		" breakables=", breakables.size(),
		" pickup_before=", pickups_before, " broke_and_dropped=", broke_ok,
		" player=", _level.get("player") != null,
		" boss=", _level.get("boss") != null)
	return true
