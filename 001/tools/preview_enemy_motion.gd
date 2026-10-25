extends SceneTree
## Render the actual game enemy subclasses and their imported skeletal actions.

const OUT := "E:/godot_game_by_fable/_review/enemies_arp/"
const KINDS := ["crawler", "shooter", "divider", "guard", "turret", "wraith", "bomber", "spawnling"]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1260, 800)
	root.get_node("Game")._fade.modulate.a = 0
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(.065, .085, .095)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(.8, .85, .9)
	environment.environment.ambient_light_energy = .6
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -35, 0)
	light.light_energy = 1
	stage.add_child(light)
	var plane := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(100, 100)
	plane.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(.13, .16, .17)
	material.roughness = 1
	plane.material_override = material
	stage.add_child(plane)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.2
	camera.position = Vector3(4, 1.9, 6)
	stage.add_child(camera)
	camera.look_at(Vector3(0, .75, 0))
	camera.current = true
	for i in KINDS.size():
		if not OS.get_cmdline_user_args().is_empty() and KINDS[i] not in OS.get_cmdline_user_args():
			continue
		var enemy = load("res://scripts/enemy_" + KINDS[i] + ".gd").new()
		stage.add_child(enemy)
		enemy.set_physics_process(false)
		if not enemy.uses_gravity:
			enemy.position.y = .8 if KINDS[i] in ["shooter", "turret"] else .4
		for clip: String in ["Idle", "Move", "Windup", "Attack", "Hit"]:
			enemy.enemy_motion.step(0, clip, .72 if clip in ["Windup", "Attack"] else .28, false)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OUT + "godot_%03d_%s.png" % [i + 1, clip])
			print("ENEMY_RENDERED ", KINDS[i], " ", clip)
		enemy.queue_free()
		await process_frame
	stage.queue_free()
	await process_frame
	quit()
