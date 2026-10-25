extends SceneTree
## 场景里找可疑的大物件：打印所有 MeshInstance3D 的世界 AABB 尺寸与路径。

func _initialize() -> void:
	var scene_path := "res://scenes/level_1.tscn"
	var ps: PackedScene = load(scene_path)
	if ps == null:
		print("load fail")
		quit()
		return
	var root := ps.instantiate()
	get_root().add_child(root)
	await process_frame
	await process_frame
	var found := 0
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		var aabb: AABB = mi.global_transform * mi.get_aabb()
		var s: Vector3 = aabb.size
		if s.x > 2.2 or s.y > 2.2 or s.z > 2.2:
			found += 1
			print("BIG ", mi.get_path_to(root), " size=", s.snapped(Vector3(0.01, 0.01, 0.01)),
				" pos=", mi.global_position.snapped(Vector3(0.01, 0.01, 0.01)))
	print("total big meshes=", found)
	quit()
