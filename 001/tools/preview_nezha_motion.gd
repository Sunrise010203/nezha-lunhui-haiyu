extends SceneTree
## Render the playable character, its real skin and weapon attachment in isolation.

var actor: CharacterBody3D
const OUT := "E:/godot_game_by_fable/_review/nezha_arp/animation/"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var out := OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else OUT
	root.size = Vector2i(1000, 900)
	root.get_node("Game")._fade.modulate.a = 0.0
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.075, 0.095, 0.10)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.8, 0.85, 0.9)
	environment.environment.ambient_light_energy = 0.35
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -35, 0)
	light.light_energy = 0.7
	stage.add_child(light)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	floor_mesh.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.15, 0.18, 0.18)
	material.roughness = 1.0
	floor_mesh.material_override = material
	stage.add_child(floor_mesh)
	actor = load("res://scripts/player.gd").new()
	stage.add_child(actor)
	actor.set_physics_process(false)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.6
	camera.position = Vector3(4.5, 2.1, 6.0)
	stage.add_child(camera)
	camera.look_at(Vector3(0, 1.1, 0))
	camera.current = true
	await process_frame
	var player: AnimationPlayer = actor._motion.player
	var diagnostic := {}
	for clip: String in ["Idle", "FightIdle", "Run", "Jump", "Fall", "Plunge", "Stab", "Slash", "UpwardThrust", "Roll", "Death"]:
		actor._motion.current = clip
		actor.skel.reset_bone_poses()
		player.play(clip, 0.0)
		player.advance(0.0)
		var duration := player.get_animation(clip).length
		var time := duration * (0.95 if clip == "Death" else 0.33 if clip in ["Stab", "Slash"] else 0.52)
		player.seek(time, true)
		actor._update_spear_follow()
		await process_frame
		await RenderingServer.frame_post_draw
		diagnostic[clip] = {"animation": player.current_animation, "time": player.current_animation_position,
			"bones": {}}
		for bone: String in ["root.x", "hand.r", "hand.l", "head.x", "foot.l", "foot.r"]:
			var p: Vector3 = actor.skel.get_bone_global_pose(actor.skel.find_bone(bone)).origin
			diagnostic[clip]["bones"][bone] = [p.x, p.y, p.z]
		var image := root.get_texture().get_image()
		image.save_png(out + "godot_" + clip + ".png")
		print("RENDERED ", clip, " at ", time)
	var file := FileAccess.open(out + "godot_pose_diagnostic.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(diagnostic, "  "))
	stage.queue_free()
	await process_frame
	quit()
