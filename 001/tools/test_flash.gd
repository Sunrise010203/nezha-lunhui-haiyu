extends SceneTree
## 回归测试：受击白闪（Game.flash_meshes）结束后，角色的 PBR material_override 必须还原。
## 用法：'<Godot>' --path 001 --script res://tools/test_flash.gd

var _level: Node = null
var _frames := 0
var _before := ""
var _during := ""


func _initialize() -> void:
	_level = (load("res://scenes/level_1.tscn") as PackedScene).instantiate()
	root.add_child(_level)


func _mesh() -> MeshInstance3D:
	var p = _level.get("player")
	if p == null:
		return null
	for mi: MeshInstance3D in p.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh != null and mi.mesh.get_surface_count() > 0:
			return mi
	return null


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 90:
		var mi := _mesh()
		if mi == null:
			print("[flash] FAIL no mesh")
			quit(1)
			return true
		_before = str(mi.material_override)
		var g := root.get_node_or_null("Game")
		g.call("flash_meshes", _level.get("player").get("gfx"), Color(1.0, 0.3, 0.3))
		_during = str(mi.material_override)
	if _frames == 120:
		var mi := _mesh()
		var after := str(mi.material_override)
		print("[flash] before=", _before)
		print("[flash] during=", _during)
		print("[flash] after=", after)
		var ok := after == _before and _before != "null" and _during != _before
		print("[flash] RESULT=", "PASS" if ok else "FAIL")
		quit(0 if ok else 1)
		return true
	return false
