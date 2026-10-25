extends SceneTree
## 用相机空间手算屏幕占幅（不依赖 viewport 尺寸），找出画面里最大的网格。

func _initialize() -> void:
	var ps: PackedScene = load("res://scenes/level_1.tscn")
	var root := ps.instantiate()
	get_root().add_child(root)
	for i in 150:
		await process_frame
	var cam: Camera3D = null
	for n in root.find_children("*", "Camera3D", true, false):
		var c := n as Camera3D
		if c.current:
			cam = c
			break
	if cam == null:
		print("no camera")
		quit()
		return
	var xf := cam.global_transform.affine_inverse()
	var k := tan(deg_to_rad(cam.fov) * 0.5)
	var aspect := 16.0 / 9.0
	var rows: Array = []
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var box: AABB = mi.global_transform * mi.get_aabb()
		var mn := Vector2(1e9, 1e9)
		var mx := Vector2(-1e9, -1e9)
		var ok := true
		for i in 8:
			var v: Vector3 = xf * box.get_endpoint(i)
			if v.z >= -0.05:
				ok = false
				break
			var sx := (v.x / (-v.z * k * aspect) + 1.0) * 0.5
			var sy := (1.0 - v.y / (-v.z * k)) * 0.5
			var sp := Vector2(sx, sy)
			mn = mn.min(sp)
			mx = mx.max(sp)
		if not ok:
			continue
		var area := maxf(0.0, (mx.x - mn.x) * (mx.y - mn.y))
		rows.append([area, mn, mx, mi])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	for i in mini(rows.size(), 10):
		var r: Array = rows[i]
		var mi: MeshInstance3D = r[3]
		var mat := mi.get_active_material(0)
		var alb := "?"
		if mat is StandardMaterial3D:
			alb = str((mat as StandardMaterial3D).albedo_color)
		elif mat != null:
			alb = mat.get_class()
		print("BIG pct=", snappedf(r[0] * 100.0, 0.1), " x=", snappedf(r[1].x, 0.01), "..", snappedf(r[2].x, 0.01),
			" y=", snappedf(r[1].y, 0.01), "..", snappedf(r[2].y, 0.01),
			" mesh=", mi.mesh.get_class(), " alb=", alb,
			" pos=", mi.global_position.snapped(Vector3(0.1, 0.1, 0.1)),
			" parent=", mi.get_parent().name)
	quit()
