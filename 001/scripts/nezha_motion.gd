extends RefCounted
## Retargeted ARP clips; gameplay owns movement, hit windows and invulnerability.

const CLIPS := ["Idle", "FightIdle", "Run", "Jump", "Fall", "Plunge", "Land", "Roll",
	"Stab", "Slash", "ThrustSlash", "UpwardThrust", "Hit", "Death"]
const LOOPS := ["Idle", "FightIdle", "Run", "Fall"]
const ACTIONS := {"atk1": "Stab", "atk2": "Slash", "atk3": "ThrustSlash",
	"heavy": "UpwardThrust", "hurt": "Hit", "dead": "Death", "skill": "UpwardThrust"}
const DURATIONS := {"atk1": 0.30, "atk2": 0.30, "atk3": 0.42, "heavy": 0.60,
	"hurt": 0.32, "dead": 1.0, "skill": 0.55}
# Blender bone-local +Y becomes glTF bone-local -Z.
const GRIP := Vector3(0.0, 0.0, -0.042)
const GRIP_FRAMES := {"Idle": 1, "FightIdle": 1, "Run": 9, "Jump": 1, "Fall": 1, "Plunge": 1,
	"Land": 1, "Roll": 1, "Stab": 10, "Slash": 8, "ThrustSlash": 9,
	"UpwardThrust": 26, "Hit": 1, "Death": 1}

var player: AnimationPlayer
var skeleton: Skeleton3D
var current := ""
var _restart := false
var _roll_left := 0.0
var _land_left := 0.0
var _combat_left := 0.0
var _overlay_base := {}
var _weapon_axes := {}


func _init(model: Node3D) -> void:
	player = model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for clip: String in CLIPS:
		assert(player.has_animation(clip), "Missing retargeted animation: " + clip)
		player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR if clip in LOOPS else Animation.LOOP_NONE
		# The FBXs contain no weapon. Calibrate a rigid grip for each weapon style.
		skeleton.reset_bone_poses()
		player.play(clip, 0.0)
		player.seek(float(GRIP_FRAMES[clip]) / 30.0, true)
		var hand := skeleton.get_bone_global_pose(skeleton.find_bone("hand.r"))
		var direction := Vector3(0.0, 0.866, 0.5)
		if clip == "Idle":
			direction = Vector3(0.0, 0.925, 0.38)
		elif clip == "Stab":
			var left_hand := skeleton.get_bone_global_pose(skeleton.find_bone("hand.l"))
			direction = (left_hand * GRIP - hand * GRIP).normalized()
		elif clip in ["Slash", "ThrustSlash"]:
			direction = Vector3.BACK
		elif clip == "UpwardThrust":
			direction = Vector3(0.0, 0.6, 0.8)
		elif clip == "Plunge":
			direction = Vector3(0.0, -1.0, 0.12).normalized()
		_weapon_axes[clip] = (hand.basis.inverse() * direction).normalized()
	skeleton.reset_bone_poses()
	player.play("Idle")
	player.advance(0.0)
	current = "Idle"


func weapon_axis() -> Vector3:
	return _weapon_axes.get(current, _weapon_axes["Idle"])


func trigger(event: String) -> void:
	_restart = true
	if event == "dash":
		_roll_left = 0.48
	elif event == "land":
		_land_left = 0.28
	elif event == "jump":
		_roll_left = 0.0
		_land_left = 0.0
	elif event in ACTIONS:
		_roll_left = 0.0
		_land_left = 0.0
		_combat_left = 4.0


func reset() -> void:
	_roll_left = 0.0
	_land_left = 0.0
	_combat_left = 0.0
	current = ""
	_restart = true
	player.stop()
	skeleton.reset_bone_poses()
	_overlay_base.clear()


func update(actor, delta: float) -> void:
	_roll_left = maxf(_roll_left - delta, 0.0)
	_land_left = maxf(_land_left - delta, 0.0)
	_combat_left = maxf(_combat_left - delta, 0.0)
	var action: String = actor.act
	var clip := "Idle"
	var rate := 1.0
	var blend := 0.10
	if action in ACTIONS:
		clip = ACTIONS[action]
		rate = player.get_animation(clip).length / float(DURATIONS[action])
		blend = 0.025 if action in ["hurt", "dead"] else 0.035
	elif action == "plunge":
		clip = "Plunge"
		blend = 0.045
	elif actor.dash_t > 0.0 or (_roll_left > 0.0 and action == "free"):
		clip = "Roll"
		rate = player.get_animation(clip).length / 0.48
		blend = 0.025
	elif action == "swing":
		clip = "Fall"
	elif not actor.is_on_floor():
		clip = "Jump" if actor.velocity.y > 0.0 else "Fall"
		blend = 0.10
	elif action in ["charge_ring", "pull"] or actor._guard_blend > 0.01:
		clip = "FightIdle"
	elif _land_left > 0.14 or (_land_left > 0.0 and absf(actor.velocity.x) < 0.5):
		clip = "Land"
		rate = player.get_animation(clip).length / 0.28
		blend = 0.035
	elif absf(actor.velocity.x) > 0.5:
		clip = "Run"
		# The source stride covers 2.70 m per cycle at the character's native size.
		rate = clampf(absf(actor.velocity.x) / 3.56, 0.5, 2.2)
	elif _combat_left > 0.0:
		clip = "FightIdle"
	for index: int in _overlay_base:
		skeleton.set_bone_pose_rotation(index, _overlay_base[index])
	_overlay_base.clear()
	if clip != current or _restart:
		player.play(clip, blend)
		current = clip
		_restart = false
	player.speed_scale = rate
	player.advance(delta)
	_apply_overlay(actor)


func _apply_overlay(actor) -> void:
	var rotations := {}
	if actor.act == "swing":
		rotations = {"arm_stretch.l": -1.4, "arm_stretch.r": -1.4}
	elif actor.act == "charge_ring":
		rotations = {"arm_stretch.r": -0.65 - 0.35 * actor._ring_charge}
	elif actor._guard_blend > 0.01 and actor.act == "free":
		rotations = {"arm_stretch.l": -0.55 * actor._guard_blend}
	for bone: String in rotations:
		var index := skeleton.find_bone(bone)
		var base := skeleton.get_bone_pose_rotation(index)
		_overlay_base[index] = base
		var local_axis := skeleton.get_bone_global_pose(index).basis.inverse() * Vector3.RIGHT
		skeleton.set_bone_pose_rotation(index, base * Quaternion(local_axis.normalized(), float(rotations[bone])))
