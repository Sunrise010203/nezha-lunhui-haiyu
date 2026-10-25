extends SceneTree
## 按“屏幕占幅”排序，找出画面里真正大的那些网格。

func _initialize() -> void:
	var ps: PackedScene = load("res://scenes/level_1.tscn")
	var root := ps.instantiate()
	get_root().add_child(root)
	for i in 180:
		await process_frame
	var cam: Camera3D = null
	for n in root.find_children("*", "Camera3D", true, false):
		cam = n
		if cam.current:
			break
	if cam == null:
		print("no camera")
		quit()
		return
	var vp := get_root().get_viewport()
	var vs := vp.get_visible_rect().size
	var screen_area := vs.x * vs.y
	var rows: Array = []
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var box: AABB = mi.global_transform * mi.get_aabb()
		var valid := 0
		var mn := Vector2(1e9, 1e9)
		var mx := Vector2(-1e9, -1e9)
		for i in 8:
			var corner := box.get_endpoint(i)
			if cam.is_position_behind(corner):
				continue
			var sp := cam.unproject_position(corner)
			valid += 1
			mn = mn.min(sp)
			mx = mx.max(sp)
		if valid == 0:
			continue
		var area := maxf(0.0, (mx.x - mn.x) * (mx.y - mn.y))
		if area / screen_area < 0.02:
			continue
		rows.append([area / screen_area, mn, mx, mi])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	for i in mini(rows.size(), 12):
		var r: Array = rows[i]
		var mi: MeshInstance3D = r[3]
		print("SCR pct=", snappedf(r[0] * 100.0, 0.1), "% rect=", (r[1] as Vector2).snapped(Vector2(1, 1)),
			"-", (r[2] as Vector2).snapped(Vector2(1, 1)), " mesh=", mi.mesh.get_class(),
			" pos=", mi.global_position.snapped(Vector3(0.1, 0.1, 0.1)), " path=", String(root.get_path_to(mi)))
	quit()
