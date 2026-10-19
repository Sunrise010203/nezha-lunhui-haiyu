class_name PlayerCamera
extends Camera3D
## 侧视跟随相机：平滑跟随 + 朝向预判 + 震屏

var target: Node3D
var _shake := 0.0
var _look_ahead := 0.0


func _ready() -> void:
	fov = 50.0
	Game.shake_requested.connect(func(s: float) -> void:
		_shake = maxf(_shake, s))


func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var ahead_target := 0.0
	if target is Player:
		ahead_target = (target as Player).facing * 1.8
	_look_ahead = lerpf(_look_ahead, ahead_target, 2.0 * delta)

	var desired := target.global_position + Vector3(_look_ahead, 3.1, 10.2)
	desired.y = maxf(desired.y, 2.0)
	global_position = global_position.lerp(desired, 1.0 - exp(-6.0 * delta))

	var look_at_pos := Vector3(global_position.x - _look_ahead * 0.3,
		global_position.y - 2.0, target.global_position.z)
	look_at(look_at_pos + Vector3(0, 0, -0.5))

	if _shake > 0.005:
		_shake = lerpf(_shake, 0.0, 8.0 * delta)
		var off := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.25
		global_position += off
	else:
		_shake = 0.0


func snap_to_target() -> void:
	if target:
		global_position = target.global_position + Vector3(0, 3.1, 10.2)
