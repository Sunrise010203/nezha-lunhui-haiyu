extends SceneTree

const OUT := "E:/godot_game_by_fable/_review/bosses_arp/"
const ASSETS := ["01_maw", "02_warden", "03_seal_core", "04_giant_eye", "05_chiwen", "06_warden_mace"]
var failed := false
var checks: Array = []


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, label: String) -> void:
	checks.append({"ok": ok, "label": label})
	if not ok:
		failed = true
		push_error("BOSS_FAIL " + label)
	else:
		print("BOSS_PASS ", label)


func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	for asset: String in ASSETS:
		var scene = load("res://art/models/bosses_arp/" + asset + ".glb")
		check(scene is PackedScene, asset + " imported")
		if not scene is PackedScene:
			continue
		var model: Node3D = scene.instantiate()
		stage.add_child(model)
		var skeletons := model.find_children("*", "Skeleton3D", true, false)
		var players := model.find_children("*", "AnimationPlayer", true, false)
		check(skeletons.size() == 1 and players.size() == 1, asset + " one skeleton and animation player")
		var skeleton := skeletons[0] as Skeleton3D
		var player := players[0] as AnimationPlayer
		check(player.has_animation("Idle") and player.has_animation("Die"), asset + " animation library")
		var weighted := 0
		var bad := 0
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			if mesh.skin == null:
				continue
			check(mesh.get_node(mesh.skeleton) == skeleton, asset + " correct skin target")
			for surface in mesh.mesh.get_surface_count():
				var arrays := mesh.mesh.surface_get_arrays(surface)
				var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var influences := weights.size() / vertices.size()
				for vi in vertices.size():
					var total := 0.0
					for j in influences:
						total += weights[vi * influences + j]
					if total < 0.99 or total > 1.01:
						bad += 1
				weighted += vertices.size()
		check(weighted > 100 and bad == 0, asset + " all vertex weights normalized")
		var motion = preload("res://scripts/boss_motion.gd").new(model, asset.trim_prefix(asset.left(3)))
		for clip: String in ["Idle", "Move", "Windup", "Attack", "Recover", "Hit", "Summon", "Phase", "Die"]:
			motion.step(0.0, clip, 0.6)
			var valid := true
			for bone in skeleton.get_bone_count():
				valid = valid and skeleton.get_bone_global_pose(bone).is_finite()
			check(valid, asset + " finite imported pose " + clip)
		model.queue_free()
		await process_frame

	for kind: String in ["maw", "warden", "sea_eye", "chiwen"]:
		var boss = load("res://scripts/boss_" + kind + ".gd").new()
		stage.add_child(boss)
		boss.set_physics_process(false)
		check(boss.model != null and boss.boss_motion != null, kind + " actual Boss uses new asset")
		if boss.boss_motion == null:
			boss.queue_free()
			continue
		var states: Dictionary = {
			"maw": {"slam_rise":"DiveWindup", "slam_fall":"DiveAttack", "sweep":"Sweep", "summon":"Summon"},
			"warden": {"charge":"Charge", "slam_raise":"SlamWindup", "slam_impact":"SlamAttack", "barrage":"Attack"},
			"sea_eye": {"p2_tele":"Windup", "p2_recover":"Attack"},
			"chiwen": {"pounce_go":"Bite", "inhale":"Inhale", "expose":"Expose", "surge_warn":"Windup"}
		}[kind]
		for state: String in states:
			boss.state = state
			boss.state_t = 0.25
			boss._advance_enemy_motion(1.0 / 30.0)
			check(boss.boss_motion.current == states[state], kind + " state sync " + state)
		if kind == "warden":
			check(not boss.model.find_children("Warden_Mace", "MeshInstance3D", true, false).is_empty(), "warden right-hand mace included")
		if kind == "sea_eye":
			check(boss._cores.size() == 3, "sea eye three P1 instances")
			boss.active = true
			boss.phase = 1
			for core in boss._cores:
				check(core.model != null and core.motion != null, "seal core fitted ARP model")
				core.take_damage(180.0, -1.0)
			check(boss.phase == 2 and boss.hp == 180.0 and boss._p2_root.visible, "three cores break then P2 appears")
			boss._cast_kind = "pulse"
			boss.state = "p2_recover"
			boss._advance_enemy_motion(0.03)
			check(boss.boss_motion.current == "Pulse", "sea eye pulse clip")
		if kind == "chiwen":
			boss._enter_phase(3)
			boss._advance_enemy_motion(0.03)
			check(boss.core_mi.visible and boss._ucore.collision_layer == 4, "chiwen P3 core and hurtpoint open")
		boss.reset_fight()
		check(boss.phase == 1 and not boss.active and boss.boss_motion.current == "Idle", kind + " reset returns to rest")
		if kind == "sea_eye":
			check(not boss._p2_root.visible and boss._cores[0].hp == 180.0 and not boss._cores[0].broken, "sea eye reset restores P1")
		if kind == "chiwen":
			check(not boss.core_mi.visible and boss._ucore.collision_layer == 0, "chiwen reset closes core")
		boss.die()
		check(boss.boss_motion.current == "Die", kind + " death clip")
		boss.queue_free()
		await process_frame

	var file := FileAccess.open(OUT + "godot_motion_tests.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"failed":failed,"checks":checks}, "  "))
	stage.queue_free()
	await process_frame
	await create_timer(2.5, true, false, true).timeout
	print("BOSS_MOTION_TESTS FAILED=", failed)
	quit(1 if failed else 0)
