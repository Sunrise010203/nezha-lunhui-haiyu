extends SceneTree
## 列出相机附近的网格件（近距离物体会在画面上显得巨大）。

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
	var cp := cam.global_position
	print("cam=", cp.snapped(Vector3(0.01, 0.01, 0.01)))
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var d := mi.global_position.distance_to(cp)
		if d > 9.0:
			continue
		var s: Vector3 = mi.get_aabb().size * mi.global_transform.basis.get_scale().abs()
		print("NEAR d=", snappedf(d, 0.01), " pos=", mi.global_position.snapped(Vector3(0.01, 0.01, 0.01)),
			" size=", s.snapped(Vector3(0.01, 0.01, 0.01)), " mesh=", mi.mesh.get_class(),
			" path=", String(root.get_path_to(mi)))
	quit()
