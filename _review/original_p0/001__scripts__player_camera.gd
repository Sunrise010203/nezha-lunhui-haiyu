class_name PlayerCamera
extends Camera3D
## 侧视跟随相机：平滑跟随 + 朝向预判 + 震屏 + Boss 战双目标取景
## 取景参数（评审 D-05）：
##   距离 10.2→8.8（角色占屏高 ~16%→~20%）
##   视线抬高（look 偏移 -2.0→-1.35，少露下半屏的空台面）
##   预判 1.8→2.6（横版动作看前方更重要）
## Boss 战：set_focus_target() 让镜头同时框住玩家与 Boss，
##   否则 Boss 在 30 米宽的场地里移动时会不断跑出画面（看起来像"反复闪现"）。

const BASE_DIST := 8.8
const BASE_LOOK_BIAS := -1.35
const BASE_AHEAD := 2.6
const BASE_HEIGHT := 2.9

var target: Node3D
var focus_target: Node3D = null   # Boss 战时的第二取景目标
var _shake := 0.0
var _look_ahead := 0.0
var _dist := BASE_DIST
var _dist_goal := BASE_DIST
var _look_bias := BASE_LOOK_BIAS
var _bias_goal := BASE_LOOK_BIAS
var _focus_extra := 0.0


func _ready() -> void:
	fov = 50.0
	Game.shake_requested.connect(func(s: float) -> void: _shake = maxf(_shake, s))


func _focus_center() -> Vector3:
	## 有第二目标时取两者中点（略偏向 Boss），没有时就是玩家
	var center := target.global_position
	if focus_target and is_instance_valid(focus_target):
		center = center.lerp(focus_target.global_position, 0.55)
	return center


func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return

	# 双目标时按两者距离拉远镜头，保证都留在画面内
	var want_extra := 0.0
	if focus_target and is_instance_valid(focus_target):
		var sep := target.global_position.distance_to(focus_target.global_position)
		want_extra = clampf(sep * 0.55, 0.0, 6.5)
	_focus_extra = lerpf(_focus_extra, want_extra, 3.0 * delta)

	_dist = lerpf(_dist, _dist_goal, 2.5 * delta)
	_look_bias = lerpf(_look_bias, _bias_goal, 2.5 * delta)

	var ahead_target := 0.0
	if target is Player:
		ahead_target = (target as Player).facing * BASE_AHEAD
	_look_ahead = lerpf(_look_ahead, ahead_target, 2.0 * delta)

	var center := _focus_center()
	var desired := center + Vector3(_look_ahead, BASE_HEIGHT, _dist + _focus_extra)
	desired.y = maxf(desired.y, 2.0)
	global_position = global_position.lerp(desired, 1.0 - exp(-6.0 * delta))

	var look_at_pos := Vector3(global_position.x - _look_ahead * 0.3,
		global_position.y + _look_bias, target.global_position.z)
	look_at(look_at_pos + Vector3(0, 0, -0.5))

	if _shake > 0.005:
		_shake = lerpf(_shake, 0.0, 8.0 * delta)
		var off := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.25
		global_position += off
	else:
		_shake = 0.0


func set_focus_target(node: Node3D) -> void:
	## 传入 Boss 开双目标取景；传 null 恢复普通跟随
	focus_target = node


func set_framing(extra_dist: float, extra_look: float) -> void:
	## Boss 战等需要特殊构图时调用；传 0, 0 恢复常规取景
	_dist_goal = BASE_DIST + extra_dist
	_bias_goal = BASE_LOOK_BIAS + extra_look


func snap_to_target() -> void:
	if target:
		_dist = _dist_goal
		_look_bias = _bias_goal
		var center := _focus_center()
		global_position = center + Vector3(0, BASE_HEIGHT, _dist + _focus_extra)
