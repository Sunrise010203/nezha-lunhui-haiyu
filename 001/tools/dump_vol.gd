extends SceneTree
## 打印场景中体积最大的 18 个网格件（含位置），用于定位悬空黑锥。

func _initialize() -> void:
	var ps: PackedScene = load("res://scenes/level_1.tscn")
	var root := ps.instantiate()
	get_root().add_child(root)
	await process_frame
	await process_frame
	var rows: Array = []
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		var gp := mi.global_position
		var s: Vector3 = mi.get_aabb().size * mi.global_transform.basis.get_scale().abs()
		rows.append([s.x * s.y * s.z, gp, s, String(mi.get_parent().name)])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	for i in mini(rows.size(), 18):
		var r: Array = rows[i]
		print("V pos=", r[1].snapped(Vector3(0.01, 0.01, 0.01)), " size=", r[2].snapped(Vector3(0.01, 0.01, 0.01)),
			" parent=", r[3])
	quit()
