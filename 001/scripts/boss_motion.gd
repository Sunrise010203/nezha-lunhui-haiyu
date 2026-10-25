extends RefCounted
## Visual-only ARP playback. AI retains movement, hitboxes and damage timing.

var player: AnimationPlayer
var skeleton: Skeleton3D
var kind: String
var current := ""
var _clock := 0.0
var _core_open := false
var _slam_recovery := false
var _blend_left := 0.0
var _blend_from: Array[Transform3D] = []


func _init(model: Node3D, boss_kind: String) -> void:
	kind = boss_kind
	player = model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var library := player.get_animation_library("").duplicate() as AnimationLibrary
	player.remove_animation_library("")
	player.add_animation_library("", library)
	for name: StringName in library.get_animation_list():
		var animation := library.get_animation(name).duplicate() as Animation
		animation.loop_mode = Animation.LOOP_LINEAR if name in ["Idle", "Move", "Charge", "Sweep", "Inhale", "Expose"] else Animation.LOOP_NONE
		library.remove_animation(name)
		library.add_animation(name, animation)
	reset()


func reset() -> void:
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	current = ""
	_core_open = false
	_slam_recovery = false
	_blend_left = 0.0
	step(0.0, "Idle")


func die() -> void:
	# EnemyBase stops physics on death; AnimationPlayer finishes independently.
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
	player.play("Die", 0.08)
	player.advance(0.0)
	current = "Die"


func step(delta: float, clip: String, phase := -1.0) -> void:
	assert(player.has_animation(clip), "Missing Boss clip: " + clip)
	if current != clip:
		_blend_from.clear()
		for bone in skeleton.get_bone_count():
			_blend_from.append(skeleton.get_bone_pose(bone))
		_blend_left = 0.08 if delta > 0.0 else 0.0
		player.play(clip, 0.0)
		current = clip
		_clock = 0.0
	_clock += delta
	var animation := player.get_animation(clip)
	var time := maxf(phase, 0.0) * animation.length if phase >= 0.0 else _clock
	if animation.loop_mode == Animation.LOOP_LINEAR:
		time = fposmod(time, maxf(animation.length, 0.001))
	else:
		time = clampf(time, 0.0, animation.length)
	player.seek(time, true)
	_blend_left = maxf(0.0, _blend_left - delta)
	if _blend_left > 0.0:
		for bone in skeleton.get_bone_count():
			skeleton.set_bone_pose(bone, _blend_from[bone].interpolate_with(skeleton.get_bone_pose(bone), 1.0 - _blend_left / 0.08))
	skeleton.force_update_all_bone_transforms()
	if _core_open:
		var chest := skeleton.find_bone("cc_chest")
		if chest >= 0:
			var basis := skeleton.get_bone_global_rest(chest).basis.inverse()
			skeleton.set_bone_pose_rotation(chest, skeleton.get_bone_pose_rotation(chest) * Quaternion(basis * Vector3.RIGHT, 0.12))
			skeleton.set_bone_pose_position(chest, skeleton.get_bone_pose_position(chest) + basis * Vector3(0.0, 0.0, 0.025))
			skeleton.force_update_all_bone_transforms()


func open_core(on: bool) -> void:
	_core_open = on


func step_encounter(delta: float, boss) -> void:
	var state: String = boss.get("state")
	var t: float = boss.get("state_t")
	var clip := "Idle"
	var phase := -1.0
	match kind:
		"maw":
			match state:
				"slam_rise": clip = "DiveWindup"; phase = t / 0.7
				"slam_hold": clip = "DiveWindup"; phase = 1.0
				"slam_fall": clip = "DiveAttack"; phase = t / 0.16
				"slam_recover": clip = "Recover"; phase = t
				"sweep_aim": clip = "Windup"; phase = t / 0.85
				"sweep": clip = "Sweep"
				"summon": clip = "Summon"; phase = t / 1.1
				"barrage":
					clip = "Windup" if t < 0.6 else "Attack"
					phase = t / 0.6 if t < 0.6 else clampf(fposmod(t - 0.6, 0.95) / 0.35, 0.0, 1.0)
		"warden":
			if state in ["slam_raise", "slam_impact"]:
				_slam_recovery = true
			elif state in ["idle", "charge_aim", "charge", "barrage_aim", "barrage", "summon"]:
				_slam_recovery = false
			match state:
				"idle": clip = "Move" if absf(boss.velocity.x) > 0.15 else "Idle"
				"charge_aim": clip = "Windup"; phase = t / maxf(float(boss.get("_aim_time")), 0.01)
				"charge": clip = "Charge"
				"slam_raise": clip = "SlamWindup"; phase = t / 0.75
				"slam_impact": clip = "SlamAttack"; phase = t / 0.22
				"barrage_aim": clip = "Windup"; phase = t / 0.6
				"barrage": clip = "Attack"; phase = clampf(t / 0.25, 0.0, 1.0)
				"summon": clip = "Summon"; phase = t / 1.2
				"recover": clip = "SlamRecover" if _slam_recovery else "Recover"; phase = t / maxf(float(boss.get("_recover_time")), 0.01)
		"giant_eye":
			match state:
				"p2_tele": clip = "Windup"; phase = t / maxf(float(boss.get("_tele_time")), 0.01)
				"p2_recover":
					clip = "Pulse" if boss.get("_cast_kind") == "pulse" else "Attack"
					phase = t / maxf(float(boss.get("_recover_time")), 0.01)
		"chiwen":
			match state:
				"intro", "phase_shift": clip = "Phase"; phase = t / 1.2
				"sweep_aim": clip = "Windup"; phase = t / 0.42
				"pounce_aim": clip = "Windup"; phase = t / 0.38
				"pounce_go": clip = "Bite"; phase = t / 0.55
				"sweep_hit": clip = "Attack"; phase = t / 0.3
				"inhale": clip = "Inhale"
				"expose": clip = "Expose"
				"recover": clip = "Recover"; phase = t / maxf(float(boss.get("_recover_time")), 0.01)
				"idle": clip = "Move"
				"fan_end", "surge_push", "ring_end": clip = "Attack"; phase = clampf(t / 0.3, 0.0, 1.0)
				"pillar": clip = "Windup"; phase = clampf(t, 0.0, 1.0)
				"surge_warn": clip = "Windup"; phase = t / 1.2
				"summon": clip = "Summon"; phase = t / 1.1
				_:
					if state.ends_with("_aim") or state == "inhale_wind":
						clip = "Windup"; phase = clampf(t / 0.7, 0.0, 1.0)
	if not boss.dead and boss.hurt_t > 0.0:
		clip = "Hit"
		phase = -1.0
	step(delta, clip, phase)


func look(yaw: float, pitch: float) -> void:
	var index := skeleton.find_bone("cc_eye")
	if index < 0:
		return
	var basis := skeleton.get_bone_global_rest(index).basis.inverse()
	var rotation := Quaternion(basis * Vector3.UP, clampf(yaw, -0.045, 0.045)) * Quaternion(basis * Vector3.RIGHT, clampf(pitch, -0.035, 0.035))
	skeleton.set_bone_pose_rotation(index, skeleton.get_bone_pose_rotation(index) * rotation)
	skeleton.force_update_all_bone_transforms()
