extends SceneTree
## Isolated real-physics regression for the playable ARP character.

var actor: CharacterBody3D
var checks: Array[String] = []
var failed := false
## 每个状态实际等待的物理帧数（真实边界距离，写进报告当证据）
var wait_frames_seen := {}


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, label: String) -> void:
	if not condition:
		failed = true
		push_error("NEZHA_MOTION_FAIL " + label)
	else:
		checks.append(label)
		print("PASS ", label)


func frames(count: int) -> void:
	for index in count:
		await physics_frame
		await process_frame


## 等待动画状态到达 state，按真实物理步推进，最多 max_frames 帧（超时返回 false）。
## 替代固定帧数的原因：`NezhaMotion` 的 Land 分支要 `_land_left <= 0.14` 才回 Idle，
## 而 `_land_left` 起手是 0.28s、每帧减 delta（约 8~9 帧），再叠加出生后的落地时间，
## 总共 11~12 帧；固定 `frames(8)` 在"首帧物理步时序"不同的机器上必然红（final-review F2）。
func wait_state(state: String, max_frames := 120) -> bool:
	for index in max_frames:
		if actor._motion.current == state:
			if index > 0:
				wait_frames_seen[state] = index
			return true
		await frames(1)
	return actor._motion.current == state


## 等待任意条件成立，按真实物理步推进，最多 max_frames 帧（超时返回 false）。
func wait_until(predicate: Callable, max_frames := 180) -> bool:
	for index in max_frames:
		if predicate.call():
			return true
		await frames(1)
	return predicate.call()

func grip_error() -> float:
	var skeleton: Skeleton3D = actor.skel
	var hand := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("hand.r"))
	var expected: Vector3 = hand * actor.NezhaMotion.GRIP
	var actual: Vector3 = actor.spear.global_transform * Vector3(0.0, -0.25, 0.0)
	return actual.distance_to(expected)


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(100, 1, 10)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position.y = -0.5
	world.add_child(floor_body)
	actor = load("res://scripts/player.gd").new()
	world.add_child(actor)
	# 先等第一次物理步落地，再等 Land → Idle 的状态边界（Land 收尾由 0.28s→0.14s 计时决定）
	var grounded_at := 0
	for index in 120:
		if actor._motion != null and actor.is_on_floor():
			grounded_at = index
			break
		await frames(1)
	wait_frames_seen["grounded"] = grounded_at
	check(actor.is_on_floor(), "grounded")
	check(actor._motion != null, "retargeted controller active")
	var animation: AnimationPlayer = actor._motion.player
	var skeleton: Skeleton3D = actor.skel
	check(skeleton.get_bone_count() == 67, "actual 67-bone skin")
	var anim_root: Node = animation.get_node(animation.root_node)
	for clip: String in actor.NezhaMotion.CLIPS:
		check(animation.has_animation(clip), "clip " + clip)
		var motion := animation.get_animation(clip)
		var driven := {}
		var valid_tracks := true
		for track in motion.get_track_count():
			var path := motion.track_get_path(track)
			var target := anim_root.get_node_or_null(NodePath(path.get_concatenated_names()))
			valid_tracks = valid_tracks and target == skeleton and path.get_subname_count() == 1 and skeleton.find_bone(path.get_subname(0)) >= 0
			driven[String(path.get_subname(0))] = true
		check(valid_tracks, "tracks resolve to actual skeleton " + clip)
		# Godot strips constant rest/finger tracks; inherited bones need no redundant keys.
		var required := ["spine_02.x", "head.x", "arm_stretch.l", "arm_stretch.r",
			"hand.l", "hand.r", "thigh_stretch.l", "thigh_stretch.r", "leg_stretch.l", "leg_stretch.r"]
		if clip not in ["Jump", "Fall", "Plunge"]:
			required.append("root.x")
		check(driven.has_all(required), "anatomical chains animated " + clip)
	# Land 分支要 _land_left 降到 0.14 以下才回 Idle（约 8~9 帧），等边界而不是固定帧数
	await wait_state("Idle", 90)
	check(actor._motion.current == "Idle", "breathing idle selected")
	var x0 := actor.position.x
	Input.action_press("move_right")
	await wait_until(func() -> bool: return actor._motion.current == "Run" \
		and actor.position.x > x0 + 0.5, 120)
	check(actor._motion.current == "Run" and actor.position.x > x0 + 0.5, "run moves collider")
	check(absf(actor.position.z) < 0.001, "side-scroller plane preserved")
	check(grip_error() < 0.002, "weapon follows running hand")
	Input.action_release("move_right")
	await wait_state("Idle", 90)
	Input.action_press("move_left")
	await wait_until(func() -> bool: return actor.facing < 0 \
		and absf(angle_difference(actor.gfx.rotation.y, PI)) < 0.1, 120)
	check(actor.facing < 0 and absf(angle_difference(actor.gfx.rotation.y, PI)) < 0.1, "left facing")
	Input.action_release("move_left")
	await wait_state("Idle", 90)
	Input.action_press("jump")
	await wait_state("Jump", 60)
	await frames(2)   # 让 Jump 姿势在本帧真正落到骨架
	check(actor._motion.current == "Jump", "jump takeoff")
	var root_index := skeleton.find_bone("root.x")
	var air_root := skeleton.get_bone_global_pose(root_index).origin
	check(absf(air_root.y - skeleton.get_bone_global_rest(root_index).origin.y) < 0.03,
		"jump has no duplicate root lift")
	Input.action_release("jump")
	var saw_fall := false
	var saw_land := false
	# 落地时长由物理轨迹决定，按状态边界等待并设超时（不是固定 70 帧）
	for index in 240:
		await frames(1)
		saw_fall = saw_fall or actor._motion.current == "Fall"
		saw_land = saw_land or actor._motion.current == "Land"
		if saw_fall and saw_land and actor.is_on_floor():
			break
	check(saw_fall and saw_land and actor.is_on_floor(), "fall to landing sequence")
	actor._do_jump()
	await wait_state("Jump", 60)
	actor._do_jump(true)
	await wait_state("Jump", 60)
	check(actor._motion.current == "Jump", "double jump restarts authored takeoff")
	# Allow enough altitude for the full entry blend before testing the impact.
	actor.position.y = 4.0
	actor._start_action("plunge")
	await wait_state("Plunge", 60)
	await frames(2)   # 姿势与速度都落到本帧
	check(actor.act == "plunge" and actor._motion.current == "Plunge", "dedicated plunge instead of generic fall")
	check(actor.velocity.y <= -20.0, "plunge speed unchanged")
	check(grip_error() < 0.002, "plunge weapon grip")
	var tip_axis: Vector3 = actor.spear.global_basis.y.normalized()
	check(tip_axis.dot(Vector3.DOWN) > 0.9, "plunge spear points down")
	await wait_until(func() -> bool: return actor.is_on_floor() and actor.act == "free", 240)
	check(actor.is_on_floor() and actor.act == "free" and actor._motion.current != "Plunge", "plunge exits on impact")
	for state: String in ["atk1", "atk2", "atk3", "heavy", "skill"]:
		actor._start_action(state)
		await wait_state(str(actor.NezhaMotion.ACTIONS[state]), 60)
		check(actor._motion.current == actor.NezhaMotion.ACTIONS[state], "state " + state)
		check(grip_error() < 0.002, "weapon grip " + state)
		await frames(45)
	await wait_until(func() -> bool: return actor._motion.current == "FightIdle", 120)
	check(actor._motion.current == "FightIdle", "combat idle after attacks")
	actor.set_physics_process(false)
	for state: String in ["swing", "charge_ring", "free"]:
		actor.act = state
		actor._guard_blend = 0.8 if state == "free" else 0.0
		actor._motion.trigger(state)
		actor._motion.update(actor, 0.0)
		var arm_index := skeleton.find_bone("arm_stretch.l")
		var first_pose := skeleton.get_bone_pose_rotation(arm_index)
		for index in 90:
			actor._motion.update(actor, 0.0)
		check(first_pose.angle_to(skeleton.get_bone_pose_rotation(arm_index)) < 0.001, "overlay does not accumulate " + state)
	actor._guard_blend = 0.0
	actor.act = "free"
	actor.set_physics_process(true)
	actor._do_dash(1.0)
	await wait_state("Roll", 60)
	check(actor._motion.current == "Roll", "dash roll")
	await wait_until(func() -> bool: return actor._motion.current != "Roll", 180)
	check(actor._motion.current != "Roll", "roll recovery")
	actor.invuln = 0.0
	actor.take_damage(1.0, actor.global_position.x + 2)
	await wait_state("Hit", 60)
	check(actor._motion.current == "Hit", "hit reaction")
	await wait_until(func() -> bool: return actor.act == "free", 180)
	actor.invuln = 0.0
	actor.take_damage(999.0, actor.global_position.x + 2)
	await wait_state("Death", 60)
	var first_head: Vector3 = skeleton.get_bone_global_pose(skeleton.find_bone("head.x")).origin
	check(actor._motion.current == "Death" and actor.gfx.visible, "visible death animation")
	await frames(40)
	var last_head: Vector3 = skeleton.get_bone_global_pose(skeleton.find_bone("head.x")).origin
	check(first_head.distance_to(last_head) > 0.1, "death advances after gameplay stops")
	actor.respawn(Vector3.ZERO)
	await wait_until(func() -> bool: return actor.act == "free" and actor._motion.current != "Death", 120)
	check(actor.act == "free" and actor._motion.current != "Death", "respawn exits death")
	await wait_until(func() -> bool: return actor._motion.current == "Idle" and actor.gfx.visible, 240)
	check(actor._motion.current == "Idle" and actor.gfx.visible, "respawn settles to visible idle")
	var report := {"passed": not failed, "checks": checks.size(), "grip_error_m": grip_error()}
	print("NEZHA_WAIT_FRAMES ", JSON.stringify(wait_frames_seen))
	var file := FileAccess.open("E:/godot_game_by_fable/_review/nezha_arp/animation/gameplay_validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	print("NEZHA_GAMEPLAY_VALIDATION ", JSON.stringify(report))
	actor.queue_free()
	world.queue_free()
	await process_frame
	quit(1 if failed else 0)
