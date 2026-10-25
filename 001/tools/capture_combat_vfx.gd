extends SceneTree

const OUT := "E:/godot_game_by_fable/_review/combat_vfx/"
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280,720)
	var level = load("res://scenes/level_1.tscn").instantiate()
	root.add_child(level)
	while not level.build_done:
		await process_frame
	root.get_node("Game")._fade.modulate.a = 0
	var actor = level.player
	actor.set_physics_process(false)
	for enemy in get_nodes_in_group("enemies"):
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
	var camera := root.get_camera_3d()
	camera.set_process(false)
	camera.set_physics_process(false)
	actor.position = Vector3(7,0.2,0)
	camera.position = actor.position + Vector3(0,4,15)
	camera.look_at(actor.position + Vector3(0,1,0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 9
	for i in 30:
		await process_frame
	for effect in ["slash", "guard", "nova", "slam", "parry"]:
		actor.act = "free"
		match effect:
			"slash":
				actor._start_action("heavy")
				actor.act_t = 0.33
				actor._process_action()
				actor._motion.update(actor, 0.33)
				actor._update_spear_follow()
			"guard":
				actor._build_tide_fx()
				actor._guard_blend = 1
				actor._update_tide_fx(0)
			"nova": actor._do_nova()
			"slam": CombatVFX.slam(level, actor.global_position, true)
			"parry":
				var projectile = load("res://scripts/projectile.gd").new()
				level.add_child(projectile)
				projectile.position = actor.position + Vector3(1,1,0)
				actor._tide_guard_t = actor.TIDE_PARRY_WINDOW
				actor._tide_reuse_t = 0
				actor.try_parry_projectile(projectile)
		await create_timer(0.07).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT + effect + ".png")
		print("CAPTURE ", effect, " effects=",get_node_count_in_group("combat_vfx_transient")," draws=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		actor._tide_cancel()
		await create_timer(1.2).timeout
	level.queue_free()
	await process_frame
	quit()
