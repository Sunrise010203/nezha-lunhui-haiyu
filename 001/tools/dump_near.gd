extends SceneTree
## 打印起点附近（x -6..22, y 1..14）所有网格件，按屏幕尺寸降序。

func _initialize() -> void:
	var ps: PackedScene = load("res://scenes/level_1.tscn")
	var root := ps.instantiate()
	get_root().add_child(root)
	for i in 90:
		await process_frame
	var rows: Array = []
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		var gp := mi.global_position
		if gp.x < -20.0 or gp.x > 30.0 or gp.y < 3.0 or gp.y > 16.0:
			continue
		var s: Vector3 = mi.get_aabb().size * mi.global_transform.basis.get_scale().abs()
		rows.append([s.x * s.y, gp, s, String(mi.get_parent().name), String(mi.name)])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	for i in mini(rows.size(), 14):
		var r: Array = rows[i]
		print("M pos=", r[1].snapped(Vector3(0.01, 0.01, 0.01)), " size=", r[2].snapped(Vector3(0.01, 0.01, 0.01)),
			" parent=", r[3], " name=", r[4])
	print("count=", rows.size())
	quit()
