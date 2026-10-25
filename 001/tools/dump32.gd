extends SceneTree
## 打印 1 号关卡直接子节点 32 的全部子件。

func _initialize() -> void:
	var ps: PackedScene = load("res://scenes/level_1.tscn")
	var root := ps.instantiate()
	get_root().add_child(root)
	for i in 150:
		await process_frame
	var ch := root.get_children()
	var n := ch[32]
	print("TARGET name=", n.name, " class=", n.get_class(), " pos=", (n as Node3D).global_position)
	for c in n.get_children():
		var p := Vector3.ZERO
		var extra := ""
		if c is Node3D:
			p = (c as Node3D).global_position
		if c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
			var mi := c as MeshInstance3D
			extra = " mesh=" + mi.mesh.get_class() + " aabb=" + str(mi.get_aabb().size.snapped(Vector3(0.1, 0.1, 0.1))) + " scale=" + str(mi.scale.snapped(Vector3(0.01, 0.01, 0.01)))
		print("  sub=", c.name, " class=", c.get_class(), " pos=", p.snapped(Vector3(0.1, 0.1, 0.1)), extra)
	quit()
