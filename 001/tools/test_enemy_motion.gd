extends SceneTree
## Real imported skins, state animation, and unchanged enemy combat contracts.

const KINDS := ["crawler", "shooter", "divider", "guard", "turret", "wraith", "bomber", "spawnling"]
const BONES := [17, 25, 19, 67, 6, 13, 25, 19]
var checks: Array[String] = []
var failed := false
var enemies: Array[CharacterBody3D] = []


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, label: String) -> void:
	if ok:
		checks.append(label)
		print("PASS ", label)
	else:
		failed = true
		push_error("ENEMY_MOTION_FAIL " + label)


func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 10)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position.y = -0.5
	world.add_child(floor_body)
	var actor = load("res://scripts/player.gd").new()
	actor.position.x = 70
	world.add_child(actor)
	actor.set_physics_process(false)
	for i in KINDS.size():
		var enemy = load("res://scripts/enemy_" + KINDS[i] + ".gd").new()
		enemy.position.x = i * 8.0
		world.add_child(enemy)
		enemy.set_physics_process(false)
		enemies.append(enemy)
		check(enemy.enemy_motion != null, KINDS[i] + " new rig loaded")
		if not enemy.enemy_motion:
			continue
		var motion = enemy.enemy_motion
		var skeleton: Skeleton3D = motion.skeleton
		check(skeleton.get_bone_count() == BONES[i], KINDS[i] + " fitted skeleton")
		var skinned := false
		var bounds := AABB()
		var first := true
		for mesh: MeshInstance3D in enemy.gfx.find_children("*", "MeshInstance3D", true, false):
			if mesh.mesh and mesh.mesh.get_surface_count() > 0 and mesh.skin:
				skinned = mesh.get_node(mesh.skeleton) == skeleton
				var box_world := mesh.global_transform * mesh.get_aabb()
				bounds = box_world if first else bounds.merge(box_world)
				first = false
		check(skinned, KINDS[i] + " skin targets real skeleton")
		for clip: String in motion.CLIPS:
			var animation: Animation = motion.player.get_animation(clip)
			var valid := animation.length > 0.0
			var anim_root: Node = motion.player.get_node(motion.player.root_node)
			for track in animation.get_track_count():
				var path := animation.track_get_path(track)
				valid = valid and anim_root.get_node_or_null(NodePath(path.get_concatenated_names())) == skeleton
				valid = valid and skeleton.find_bone(path.get_subname(0)) >= 0
			check(valid, KINDS[i] + " valid tracks " + clip)
			motion.step(0.0, clip, 0.2, false)
			var a: Array[Transform3D] = []
			for bi in skeleton.get_bone_count():
				a.append(skeleton.get_bone_global_pose(bi))
			motion.step(0.0, clip, 0.7, false)
			var moved := false
			var finite := true
			for bi in skeleton.get_bone_count():
				var pose := skeleton.get_bone_global_pose(bi)
				finite = finite and pose.is_finite()
				moved = moved or not a[bi].is_equal_approx(pose)
			check(finite and moved, KINDS[i] + " deforms " + clip)
		var heights := [1.1, 1.6, 0.95, 1.7, 1.5, 1.05, 1.2, 0.95]
		check(enemy.gfx.scale.is_equal_approx(Vector3.ONE), KINDS[i] + " no whole-body squash")
		check(absf(bounds.size.y - heights[i]) < .01, KINDS[i] + " model height matches collider")
	var crawler = enemies[0]
	crawler.set_physics_process(true)
	var x0: float = crawler.position.x
	await frames(25)
	check(crawler.position.x > x0 + 0.3 and crawler.enemy_motion.current == "Move", "crawler physics drives locomotion")
	check(crawler.is_on_floor(), "crawler feet grounded")
	crawler.set_physics_process(false)
	crawler.state = "windup"
	crawler.state_t = 0.19
	crawler._advance_enemy_motion(0.016)
	check(crawler.enemy_motion.current == "Windup", "crawler windup phase")
	crawler._behave(0.2)
	crawler._advance_enemy_motion(0.016)
	check(crawler.state == "lunge" and crawler.enemy_motion.current == "Attack" and crawler.velocity.x == crawler.move_dir * 11, "crawler lunge timing and speed")
	crawler.stun(0.3)
	crawler._advance_enemy_motion(0.016)
	check(crawler.enemy_motion.current == "Hit", "stun selects skeletal hit")
	var shooter = enemies[1]
	var count := get_nodes_in_group("projectiles").size()
	shooter._shoot()
	shooter._advance_enemy_motion(0.016)
	check(get_nodes_in_group("projectiles").size() == count + 1 and shooter.enemy_motion.current == "Attack", "shooter shot and recoil")
	var projectile = get_nodes_in_group("projectiles").back()
	check(projectile.dmg == 10 and is_equal_approx(projectile.vel.length(), 7.5), "shooter damage and speed unchanged")
	check(shooter.enemy_motion._blend_left > 0, "skeletal transitions blend")
	shooter._advance_enemy_motion(.23)
	check(shooter.enemy_motion.current == "Recover", "shooter recoil returns through recovery")
	shooter._advance_enemy_motion(.22)
	check(shooter.enemy_motion.current == "Idle", "shooter recovery returns to idle")
	var guard = enemies[3]
	guard.facing = 1
	guard.take_damage(10, -1, false)
	check(is_equal_approx(guard.hp, 91.5), "guard front shield reduction")
	guard.take_damage(10, 1, false)
	check(is_equal_approx(guard.hp, 81.5), "guard back full damage")
	guard.hurt_t = 0
	guard._enter_tele()
	guard._advance_enemy_motion(.01)
	check(guard.enemy_motion.current == "Windup", "guard telegraph without procedural shield")
	guard._behave(.56)
	guard._advance_enemy_motion(.01)
	check(guard.state == "bash" and guard.enemy_motion.current == "Attack", "guard bash state animation")
	var turret = enemies[4]
	actor.position = turret.position + Vector3(7, 1, 0)
	count = get_nodes_in_group("projectiles").size()
	turret._enter_fire()
	for i in 3:
		turret._behave(.13)
	turret._advance_enemy_motion(.01)
	check(get_nodes_in_group("projectiles").size() == count + 3 and turret.enemy_motion.current == "Attack", "turret three-shot volley and recoil")
	projectile = get_nodes_in_group("projectiles").back()
	check(projectile.dmg == 9 and is_equal_approx(projectile.vel.length(), 8), "turret damage and speed unchanged")
	var wraith = enemies[5]
	wraith._enter_tele()
	wraith._advance_enemy_motion(.01)
	check(wraith.enemy_motion.current == "Windup", "wraith telegraph")
	wraith._behave(.56)
	wraith._advance_enemy_motion(.01)
	check(wraith.state == "dash" and wraith.enemy_motion.current == "Attack" and absf(wraith.velocity.x) == 18, "wraith dash speed and animation")
	var divider = enemies[2]
	divider.take_damage(999, 1)
	check(divider.offspring.size() == 2, "divider spawns exactly two children")
	for child in divider.offspring:
		child.set_physics_process(false)
		check(child.generation == 1 and child.hp == 18 and child.enemy_motion != null and child._art.scale.is_equal_approx(Vector3.ONE * .6), "divider child rig scale and hp")
	check(divider.offspring[0].enemy_motion.player.get_animation_library("") != divider.offspring[1].enemy_motion.player.get_animation_library(""), "instances have independent animation libraries")
	var bomber = enemies[6]
	actor.position = bomber.position + Vector3(1, 0, 0)
	bomber.take_damage(999, 1)
	bomber.hurt_t = 0
	bomber._advance_enemy_motion(.01)
	check(not bomber.dead and bomber.state == "fuse" and bomber.enemy_motion.current == "Windup", "bomber lethal damage retains fuse")
	bomber._set_heat(.8)
	check(bomber._light.light_energy > 3.0, "bomber retains escalating warning light")
	bomber._behave(.2)
	check(not bomber.dead, "bomber survives until fuse expires")
	bomber._behave(.26)
	check(bomber.dead and bomber._exploded, "bomber explodes at original fuse duration")
	var spawnling = enemies[7]
	check(spawnling.max_hp == 40 and spawnling.touch_damage == 10 and spawnling.parryable_melee, "spawnling combat stats unchanged")
	actor.position = spawnling.position + Vector3(2, 0, 0)
	spawnling.state = "chase"
	spawnling._behave(.016)
	spawnling._advance_enemy_motion(.016)
	check(spawnling.state == "windup" and spawnling.parry_window_open() and spawnling.enemy_motion.current == "Windup", "spawnling windup opens parry window")
	spawnling._behave(.39)
	check(spawnling.state == "windup", "spawnling retains full 0.4 second telegraph")
	spawnling._behave(.011)
	spawnling._advance_enemy_motion(.016)
	check(spawnling.state == "lunge" and spawnling.enemy_motion.current == "Attack" and spawnling.velocity.x == 10 and spawnling.velocity.y == 3, "spawnling original lunge impulse")
	actor.position.x += 20
	spawnling._behave(.451)
	spawnling._advance_enemy_motion(.016)
	check(spawnling.state == "recover" and spawnling.enemy_motion.current == "Recover", "spawnling lunge returns through recovery")
	spawnling._behave(.301)
	check(spawnling.state == "chase" and spawnling.lunge_cd == 1.5, "spawnling original recovery and cooldown")
	spawnling.take_damage(10, 1)
	check(spawnling.hp == 35 and spawnling._shell, "spawnling shell halves damage")
	spawnling.on_parried(spawnling.position.x - 1)
	spawnling._advance_enemy_motion(.016)
	check(not spawnling._shell and spawnling.hp == 5 and spawnling._stun_t > 0 and spawnling.enemy_motion.current == "Hit", "spawnling parry breaks shell and staggers")
	check(spawnling.gfx.scale.is_equal_approx(Vector3.ONE), "spawnling state animation does not squash model")
	spawnling.take_damage(1, 1)
	check(spawnling.hp == 4, "spawnling broken shell takes full damage")
	spawnling.hurt_t = 0
	spawnling._stun_t = 0
	spawnling.position = Vector3(-20, 0, 0)
	spawnling.patrol_min = -25
	spawnling.patrol_max = -15
	spawnling.state = "patrol"
	spawnling.move_dir = 1
	spawnling.velocity = Vector3.ZERO
	spawnling.set_physics_process(true)
	await frames(25)
	check(spawnling.is_on_floor() and spawnling.position.x > -19.7 and spawnling.enemy_motion.current == "Move", "spawnling grounded physics locomotion")
	spawnling.set_physics_process(false)
	spawnling.move_dir = -1
	spawnling.velocity.x = -2
	for i in 20:
		spawnling._behave(.016)
	check(absf(wrapf(spawnling.gfx.rotation.y - PI, -PI, PI)) < .2, "spawnling turns toward movement")
	var file := FileAccess.open("E:/godot_game_by_fable/_review/enemies_arp/godot_tests.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": checks.size(), "failed": failed, "checks": checks}, "  "))
	world.queue_free()
	await frames(2)
	enemies.clear()
	print("ENEMY_MOTION_TESTS ", checks.size(), " FAILED=", failed)
	call_deferred("quit", 1 if failed else 0)
