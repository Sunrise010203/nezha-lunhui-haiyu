extends SceneTree
## 用相机射线 + AABB 相交，定位屏幕 (px,py) 处到底是哪块网格。

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
	print("CAM pos=", cam.global_position.snapped(Vector3(0.01, 0.01, 0.01)), " fov=", cam.fov)
	var size := Vector2(1920, 1080)
	var px := 0.49 * size.x
	var py := 0.18 * size.y
	var origin := cam.project_ray_origin(Vector2(px, py))
	var dir := cam.project_ray_normal(Vector2(px, py))
	var hits: Array = []
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var box: AABB = mi.global_transform * mi.get_aabb()
		var hp = box.intersects_ray(origin, dir)
		if hp != null:
			var dist: float = origin.distance_to(hp)
			hits.append([dist, hp, mi])
	hits.sort_custom(func(a, b): return a[0] < b[0])
	for i in mini(hits.size(), 8):
		var h: Array = hits[i]
		var mi: MeshInstance3D = h[2]
		print("HIT d=", snappedf(h[0], 0.01), " at=", (h[1] as Vector3).snapped(Vector3(0.01, 0.01, 0.01)),
			" parent=", mi.get_parent().name, " size=", (mi.get_aabb().size * mi.global_transform.basis.get_scale().abs()).snapped(Vector3(0.01,0.01,0.01)), " mesh=", mi.mesh.get_class(), " res=", mi.mesh.resource_path)
	print("hits=", hits.size())
	quit()
