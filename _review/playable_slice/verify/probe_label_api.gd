extends SceneTree
func _initialize() -> void:
	print("HAS_AABB=", ClassDB.class_has_method("Label3D", "get_aabb"))
	print("HAS_GET_AABB=", ClassDB.class_has_method("GeometryInstance3D", "get_aabb"))
	for m in ClassDB.class_get_method_list("Label3D", true):
		if "aabb" in String(m.name): print("METHOD ", m.name)
	quit()
