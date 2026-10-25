extends SceneTree
## 统计场景里所有 Node3D 的类型分布，找非 MeshInstance3D 的大体量物件。

func _initialize() -> void:
	var ps: PackedScene = load("res://scenes/level_1.tscn")
	var root := ps.instantiate()
	get_root().add_child(root)
	for i in 150:
		await process_frame
	var counts := {}
	for n in root.find_children("*", "", true, false):
		var c := n.get_class()
		counts[c] = int(counts.get(c, 0)) + 1
	var keys := counts.keys()
	keys.sort()
	for k in keys:
		print("CLASS ", k, " = ", counts[k])
	quit()
