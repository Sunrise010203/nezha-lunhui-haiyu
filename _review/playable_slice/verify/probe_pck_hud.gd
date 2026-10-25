extends SceneTree
var _frames := 0
var _level: Node = null
var _shot := "E:/godot_game_by_fable/_review/playable_slice/verify/export_run/pck_editor_ch1.png"

func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_level = (load("res://scenes/level_1.tscn") as PackedScene).instantiate()
	root.add_child(_level)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 150:
		var hud = _level.get("hud")
		print("HUD ", hud)
		if hud:
			var vp := root.get_viewport().get_visible_rect()
			print("VIEWPORT ", vp)
			var hl = hud.get("_hint_label")
			var sl = hud.get("_soul_label")
			print("HINT vis=", hl.visible, " rect=", hl.get_global_rect(), " text=", hl.text)
			print("SOUL vis=", sl.visible, " rect=", sl.get_global_rect(), " text=", sl.text)
			var rootc = hud.get("_root")
			print("HUD_ROOT size=", rootc.size, " anchors=", rootc.anchor_right, ",", rootc.anchor_bottom)
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(_shot)
		print("SHOT_SAVED ", _shot, " ", img.get_size())
		quit()
	return false
