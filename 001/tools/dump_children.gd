extends SceneTree
## 打印 level 直接子节点 20..48 的名字/类型/位置，用于定位黑色倒锥。

func _initialize() -> void:
	var ps: PackedScene = load("res://scenes/level_1.tscn")
	var root := ps.instantiate()
	get_root().add_child(root)
	for i in 150:
		await process_frame
	var ch := root.get_children()
	print("child count=", ch.size())
	for i in range(20, mini(48, ch.size())):
		var n := ch[i]
		var extra := ""
		if n is Node3D:
			extra = " pos=" + str((n as Node3D).global_position.snapped(Vector3(0.1, 0.1, 0.1)))
		print(i, " name=", n.name, " class=", n.get_class(), " children=", n.get_child_count(), extra)
	quit()
