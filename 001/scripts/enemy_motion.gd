extends RefCounted
## Visual-only animation: AI and physics retain all movement and damage timing.

const CLIPS := ["Idle", "Move", "Windup", "Attack", "Recover", "Hit"]
var player: AnimationPlayer
var skeleton: Skeleton3D
var current := ""
var _attack_left := 0.0
var _clock := 0.0
var _was_hurt := false
var _blend_left := 0.0
var _blend_from: Array[Transform3D] = []


func _init(model: Node3D) -> void:
	player = model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var library := player.get_animation_library("").duplicate() as AnimationLibrary
	player.remove_animation_library("")
	player.add_animation_library("", library)
	for clip: String in CLIPS:
		assert(player.has_animation(clip), "Missing enemy animation: " + clip)
		var animation := player.get_animation(clip).duplicate() as Animation
		animation.loop_mode = Animation.LOOP_LINEAR if clip in ["Idle", "Move"] else Animation.LOOP_NONE
		library.remove_animation(clip)
		library.add_animation(clip, animation)
	step(0.0, "Idle", -1.0, false)


func attack() -> void:
	_attack_left = 0.42
	current = ""


func step(delta: float, clip: String, phase: float, hurt: bool) -> void:
	_attack_left = maxf(0.0, _attack_left - delta)
	if _attack_left > 0.0:
		clip = "Attack" if _attack_left > 0.2 else "Recover"
		phase = (0.42 - _attack_left) / 0.22 if _attack_left > 0.2 else 1.0 - _attack_left / 0.2
	if hurt:
		clip = "Hit"
		phase = -1.0
		if not _was_hurt:
			current = ""
	_was_hurt = hurt
	if clip != current:
		_blend_from.clear()
		for bone in skeleton.get_bone_count():
			_blend_from.append(skeleton.get_bone_pose(bone))
		_blend_left = 0.08 if delta > 0.0 else 0.0
		player.play(clip, 0.0)
		current = clip
		_clock = 0.0
	_clock += delta
	var animation := player.get_animation(clip)
	var time := phase * animation.length if phase >= 0.0 else _clock
	if animation.loop_mode == Animation.LOOP_LINEAR:
		time = fposmod(time, animation.length)
	else:
		time = clampf(time, 0.0, animation.length)
	player.seek(time, true)
	_blend_left = maxf(_blend_left - delta, 0.0)
	if _blend_left > 0.0:
		for bone in skeleton.get_bone_count():
			var pose := _blend_from[bone].interpolate_with(skeleton.get_bone_pose(bone), 1.0 - _blend_left / 0.08)
			skeleton.set_bone_pose(bone, pose)
	skeleton.force_update_all_bone_transforms()
