extends SceneTree
## t6：从最终 exe 抽出的内嵌 PCK 直接渲染截图（--main-pack 指向 r2_embedded.pck）。
## 用法：
##   <Godot> --main-pack <pck> --script E:/.../shot_pack.gd -- <out.png> <x> <boss:0|1> <frames>
## x < -9000 不传送；boss=1 时第 90 帧调用 _start_boss。

var _out := "E:/godot_game_by_fable/_review/playable_slice/verify_t6/shot.png"
var _x := -9999.0
var _boss := false
var _shot_frame := 200
var _frames := 0
var _level: Node = null
var _done := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: _out = args[0]
	if args.size() > 1: _x = float(args[1])
	if args.size() > 2: _boss = args[2] == "1"
	if args.size() > 3: _shot_frame = int(args[3])
	print("=== SHOT_PACK out=", _out, " x=", _x, " boss=", _boss, " frame=", _shot_frame, " ===")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_level = (load("res://scenes/level_1.tscn") as PackedScene).instantiate()
	root.add_child(_level)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 60 and _x > -9000.0 and _level.get("player") != null:
		var p: Node3D = _level.get("player")
		p.set("hp", 1000.0)
		p.global_position = Vector3(_x, 7.0, 0.0)
		if p is CharacterBody3D:
			(p as CharacterBody3D).velocity = Vector3.ZERO
		var c = _level.get("cam")
		if c != null:
			c.call("snap_to_target")
		print("TELEPORT x=%.1f" % _x)
	if _frames == 90 and _boss:
		_level.call("_start_boss")
	if _frames == 150:
		var hud = _level.get("hud")
		if hud:
			var hl = hud.get("_hint_label")
			var sl = hud.get("_soul_label")
			print("HUD hint_vis=", hl.visible if hl else "n/a", " hint_rect=", hl.get_global_rect() if hl else "n/a")
			print("HUD soul_vis=", sl.visible if sl else "n/a", " soul_rect=", sl.get_global_rect() if sl else "n/a", " text=", sl.text if sl else "n/a")
			var vp := root.get_viewport().get_visible_rect()
			print("VIEWPORT ", vp)
		var boss = _level.get("boss")
		if boss != null:
			print("BOSS state=", boss.get("state"), " hp=", boss.get("hp"), " started=", _level.get("boss_started"))
	if _frames == _shot_frame and not _done:
		_done = true
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(_out)
		print("SHOT_SAVED ", _out, " ", img.get_size())
		var far = _level.find_child("DistantPalaceMatte", true, false)
		if far and far is GeometryInstance3D:
			var mat := (far as GeometryInstance3D).material_override
			print("FAR_MAT override=", mat)
			if mat is ShaderMaterial:
				print("FAR_TEX ", (mat as ShaderMaterial).get_shader_parameter("palace"))
		quit()
	return false
