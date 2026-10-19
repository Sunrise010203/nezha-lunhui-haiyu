extends SceneTree
## 临时探针：确认 Godot 4.6 Environment 属性名与 ProjectSettings 键名

func _initialize() -> void:
	var env := Environment.new()
	for p in ClassDB.class_get_property_list("Environment"):
		var n: String = p.name
		if n.contains("fog") or n.contains("glow") or n.contains("tonemap") or n.contains("adjustment"):
			print("ENV ", n)
	print("--- project settings ---")
	for key in ["rendering/anti_aliasing/quality/use_debanding",
			"rendering/textures/default_filters/anisotropic_filtering_level",
			"rendering/anti_aliasing/quality/msaa_3d"]:
		print("PS ", key, " has=", ProjectSettings.has_setting(key),
			" val=", ProjectSettings.get_setting(key))
	quit()
