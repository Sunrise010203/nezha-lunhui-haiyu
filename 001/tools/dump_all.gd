extends SceneTree
## 列出画面里的大件（含 MultiMesh），并标出中心高、体量大的可疑物。

func _initialize() -> void:
	var ps: PackedScene = load("res://scenes/level_1.tscn")
	var root := ps.instantiate()
	get_root().add_child(root)
	for i in 180:
		await process_frame
	print("children=", root.get_child_count())
	var rows: Array = []
	for n in root.find_children("*", "Node3D", true, false):
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			if mi.mesh == null:
				continue
			var s: Vector3 = mi.get_aabb().size * mi.global_transform.basis.get_scale().abs()
			rows.append([s.x * s.y * s.z, mi.global_position, s, "MeshInstance3D/" + mi.mesh.get_class(), String(root.get_path_to(mi))])
		elif n is MultiMeshInstance3D:
			var mm := n as MultiMeshInstance3D
			var gp := mm.global_position
			rows.append([0.001, gp, Vector3(1, 1, 1), "MultiMesh", String(root.get_path_to(mm))])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	for i in mini(rows.size(), 16):
		var r: Array = rows[i]
		print("OBJ pos=", r[1].snapped(Vector3(0.1, 0.1, 0.1)), " size=", r[2].snapped(Vector3(0.01, 0.01, 0.01)),
			" ", r[3], " path=", r[4])
	quit()
