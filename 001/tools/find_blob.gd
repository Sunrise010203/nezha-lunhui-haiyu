extends SceneTree
## 把投影落在“黑锥区域”的网格染成品红，并打印它们的父链，一次定位。

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
	var hit := 0
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var v: Vector3 = xf * mi.global_position
		if v.z >= -0.05:
			continue
		var sx := (v.x / (-v.z * k * aspect) + 1.0) * 0.5
		var sy := (1.0 - v.y / (-v.z * k)) * 0.5
		if sx < 0.38 or sx > 0.82 or sy < -0.02 or sy > 0.38:
			continue
		# 屏幕尺寸也要够大
		var ssz: Vector3 = mi.get_aabb().size * mi.global_transform.basis.get_scale().abs()
		var ang := (ssz.y / maxf(-v.z, 0.001)) / (2.0 * k)
		if ang < 0.10:
			continue
		hit += 1
		var chain := []
		var p: Node = mi
		while p != null and p != root:
			chain.push_front(p.name)
			p = p.get_parent()
		print("CAND sx=", snappedf(sx, 0.01), " sy=", snappedf(sy, 0.01),
			" ang=", snappedf(ang, 0.01), " mesh=", mi.mesh.get_class(),
			" pos=", mi.global_position.snapped(Vector3(0.1, 0.1, 0.1)),
			" chain=", "/".join(chain))
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1, 0, 1)
		mat.emission_enabled = true
		mat.emission = Color(1, 0, 1)
		mat.emission_energy_multiplier = 2.0
		mi.material_override = mat
	print("candidates=", hit)
	quit()
