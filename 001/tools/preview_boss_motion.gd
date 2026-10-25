extends SceneTree

const OUT := "E:/godot_game_by_fable/_review/bosses_arp/"


func _initialize() -> void:
	call_deferred("_run")


func shot(name: String) -> void:
	for i in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + name + ".png")
	print("BOSS_SCREENSHOT ", name)


func _run() -> void:
	root.size = Vector2i(1280, 900)
	root.get_node("Game")._fade.modulate.a = 0.0
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.065, 0.085, 0.095)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.8, 0.85, 0.9)
	environment.environment.ambient_light_energy = 0.65
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -35, 0)
	light.light_energy = 1.0
	stage.add_child(light)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(70, 70)
	floor_mesh.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.13, 0.16, 0.17)
	material.roughness = 1.0
	floor_mesh.material_override = material
	stage.add_child(floor_mesh)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	stage.add_child(camera)
	camera.current = true
	for kind: String in ["maw", "warden", "sea_eye", "chiwen"]:
		var boss = load("res://scripts/boss_" + kind + ".gd").new()
		if kind == "maw" or kind == "sea_eye":
			boss.position.y = 2.2
		stage.add_child(boss)
		boss.set_physics_process(false)
		camera.size = 6.0 if kind != "chiwen" else 7.0
		camera.position = Vector3(9, 5, 14) if kind != "sea_eye" else Vector3(0, 4.5, 18)
		camera.look_at(Vector3(0, 2.0, 0))
		if kind == "maw":
			boss.gfx.rotation.y = PI
			boss.boss_motion.step(0.0, "DiveWindup", 0.8)
		elif kind == "warden":
			boss.boss_motion.step(0.0, "Idle", 0.0)
		elif kind == "sea_eye":
			camera.size = 18.0
		await shot("game_" + kind + "_rest")
		if kind == "warden":
			boss.boss_motion.step(0.0, "SlamWindup", 0.70)
			await shot("game_warden_raise")
			boss.boss_motion.step(0.0, "SlamAttack", 0.4)
			await shot("game_warden_impact")
		if kind == "sea_eye":
			boss._core_root.visible = false
			boss._p1_root.visible = false
			boss._p2_root.visible = true
			camera.size = 5.8
			boss.boss_motion.step(0.0, "Pulse", 0.5)
			await shot("game_sea_eye_p2")
		if kind == "chiwen":
			boss.boss_motion.open_core(true)
			boss._core_open(true)
			boss.boss_motion.step(0.0, "Move", 0.25)
			await shot("game_chiwen_core")
		boss.queue_free()
		await process_frame
	stage.queue_free()
	await process_frame
	quit()
