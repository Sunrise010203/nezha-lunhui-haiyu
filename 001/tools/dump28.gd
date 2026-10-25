extends SceneTree
## 打印 1 号关卡直接子节点 28 的全部子件（定位黑色倒锥）。

func _initialize() -> void:
	var ps: PackedScene = load("res://scenes/level_1.tscn")
	var root := ps.instantiate()
	get_root().add_child(root)
	for i in 150:
		await process_frame
	var ch := root.get_children()
	var n := ch[28]
	print("TARGET name=", n.name, " class=", n.get_class(), " pos=", (n as Node3D).global_position)
	for c in n.get_children():
		var p := Vector3.ZERO
		if c is Node3D:
			p = (c as Node3D).global_position
		var extra := ""
		if c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
			extra = " mesh=" + (c as MeshInstance3D).mesh.get_class() + " aabb=" + str((c as MeshInstance3D).get_aabb().size)
		print("  sub=", c.name, " class=", c.get_class(), " pos=", p.snapped(Vector3(0.1, 0.1, 0.1)), extra)
	quit()
