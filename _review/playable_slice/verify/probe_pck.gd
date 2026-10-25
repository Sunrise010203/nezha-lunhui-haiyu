extends SceneTree
func _initialize() -> void:
	var paths := [
		"res://art/ref/ch1_palace_far.png",
		"res://art/ref/ch1_corridor.png",
		"res://art/backdrop.png",
		"res://art/models/glb_game",
		"res://scenes/env_ch1_showcase.tscn",
		"res://tools/capture.gd",
		"res://scripts/ch1_ruins.gd",
		"res://scenes/level_1.tscn",
	]
	for p in paths:
		var f := FileAccess.file_exists(p)
		var r := ResourceLoader.exists(p)
		var d := DirAccess.open(p)
		print("PROBE %s file=%s res=%s dir=%s" % [p, f, r, d != null])
	var tex = load("res://art/ref/ch1_palace_far.png")
	print("PROBE_LOAD palace=", tex)
	if tex is Texture2D:
		print("PROBE_SIZE ", (tex as Texture2D).get_size())
	var dir := DirAccess.open("res://art/ref")
	if dir:
		dir.list_dir_begin()
		var n := dir.get_next()
		var c := 0
		while n != "":
			c += 1
			n = dir.get_next()
		dir.list_dir_end()
		print("PROBE art/ref entries=", c)
	quit()
