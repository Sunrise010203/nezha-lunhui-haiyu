extends SceneTree
## 列出世界高度 y>4.5 的所有网格，带材质反照率与父节点名，用于定位悬空黑块。

func _initialize() -> void:
	var ps: PackedScene = load("res://scenes/level_1.tscn")
	var root := ps.instantiate()
	get_root().add_child(root)
	for i in 150:
		await process_frame
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var p := mi.global_position
		if p.y < 4.5:
			continue
		var alb := "nomat"
		var mat := mi.get_active_material(0)
		if mat is StandardMaterial3D:
			alb = str((mat as StandardMaterial3D).albedo_color)
		elif mat != null:
			alb = mat.get_class()
		var par := mi.get_parent()
		print("HI y=", snappedf(p.y, 0.01), " x=", snappedf(p.x, 0.1), " z=", snappedf(p.z, 0.1),
			" size=", mi.get_aabb().size.snapped(Vector3(0.1, 0.1, 0.1)),
			" mesh=", mi.mesh.get_class(), " alb=", alb,
			" parent=", (par.name if par != null else "?"),
			" gparent=", (par.get_parent().name if par != null and par.get_parent() != null else "?"))
	quit()
