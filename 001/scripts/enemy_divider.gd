class_name EnemyDivider
extends EnemyBase
## 分潮：会分裂的青绿双叶地面怪。
## 巡逻 → 发现玩家后小步追击（3.0m/s）→ 近身短扑咬（0.35s 前摇 / 12 伤害 / 1.6s 冷却）。
## 母体（generation == 0）死亡时左右各裂出 1 只子体（generation == 1）：
## 子体 HP 18 / 伤害 8 / 体型 0.6 倍，且不再分裂。
## 子体死亡同样走基类 die() → enemy_died，由关卡竞技场统一计数。

const DETECT_RANGE := 6.5       # 发现玩家
const LOSE_RANGE := 9.5         # 追丢
const PATROL_SPEED := 2.0
const CHASE_SPEED := 3.0
const BITE_WINDUP := 0.35       # 扑咬前摇
const BITE_CD := 1.6
const BITE_RANGE := 1.9
const BITE_TIME := 0.28         # 扑出后判定窗口
const CHILD_SCALE := 0.6

var patrol_min := 0.0
var patrol_max := 0.0
var generation := 0             # 0 = 母体（会分裂）；1 = 子体（不再分裂）。须在 add_child 前由生成方设置
var body_scale := 1.0           # 子体 0.6 倍体型
var offspring: Array[EnemyBase] = []   # 母体死亡时裂出的子体，供关卡竞技场/清场逻辑追踪
var state := "patrol"
var state_t := 0.0
var move_dir := 1.0
var facing := 1.0
var bite_cd := 0.0
var _contact_cd := 0.0
var _t := 0.0
var _art: Node3D
var _lobe_l: MeshInstance3D
var _lobe_r: MeshInstance3D
var _tentacles: Array[MeshInstance3D] = []
var _tent_base: Array[Vector3] = []
var _tent_rot: Array[Vector3] = []
var _core_mat: StandardMaterial3D
var _light: OmniLight3D


# ---------------------------------------------------------------- 初始化

func _setup() -> void:
	uses_gravity = true
	rim_color = Color(0.35, 1.0, 0.72, 0.85)   # 青绿边：幽暗海底里能看清
	if generation == 0:
		max_hp = 60.0
		touch_damage = 12.0
		knock_resist = 0.2
		body_scale = 1.0
	else:
		max_hp = 18.0
		touch_damage = 8.0
		knock_resist = 0.1
		body_scale = CHILD_SCALE
	hp = max_hp
	# 碰撞胶囊按体型缩放：底部对齐 y=0，子体不会陷进地面也不会浮空
	add_hitbox(0.5 * body_scale, 0.95 * body_scale, 0.475 * body_scale)
	if patrol_max <= patrol_min:
		var half := 3.0 if generation == 0 else 1.4
		patrol_min = global_position.x - half
		patrol_max = global_position.x + half
	# 子体只缩放外观，物理体保持常规尺寸（避免缩放物理体的抖动）
	if _art:
		_art.scale = Vector3.ONE * body_scale


func _build_gfx() -> void:
	_art = Node3D.new()
	_art.name = "art"
	gfx.add_child(_art)

	# 两个半透明青绿叶球（水母伞盖）
	var lobe_mat := Game.std_mat(Color(0.1, 0.76, 0.6, 0.62),
		Color(0.16, 1.0, 0.78), 0.9, 0.35, 0.1)
	lobe_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lobe_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var lobe := SphereMesh.new()
	lobe.radius = 0.3
	lobe.height = 0.6
	lobe.radial_segments = 16
	lobe.rings = 8
	_lobe_l = Game.add_mesh(_art, lobe, lobe_mat, Vector3(-0.26, 0.62, 0),
		Vector3.ZERO, Vector3(1.0, 1.18, 1.0))
	_lobe_r = Game.add_mesh(_art, lobe, lobe_mat, Vector3(0.26, 0.62, 0),
		Vector3.ZERO, Vector3(1.0, 1.18, 1.0))

	# 双叶之间的发光核
	_core_mat = Game.std_mat(Color(0.62, 1.0, 0.86), Color(0.55, 1.0, 0.85),
		3.0, 0.2)
	var core := SphereMesh.new()
	core.radius = 0.16
	core.height = 0.32
	core.radial_segments = 14
	core.rings = 7
	Game.add_mesh(_art, core, _core_mat, Vector3(0, 0.6, 0))

	# 4 条短触须（垂在叶球下方）
	var tent_mat := Game.std_mat(Color(0.08, 0.5, 0.42),
		Color(0.12, 0.75, 0.58), 0.6, 0.45)
	var tent := CylinderMesh.new()
	tent.top_radius = 0.05
	tent.bottom_radius = 0.015
	tent.height = 0.34
	tent.radial_segments = 6
	for i in 4:
		var x := -0.42 + i * 0.28
		var z := 0.08 if i % 2 == 0 else -0.08
		var base := Vector3(x, 0.24, z)
		var rot := Vector3(0, 0, -10.0 + i * 6.5)
		var mi := Game.add_mesh(_art, tent, tent_mat, base, rot)
		_tentacles.append(mi)
		_tent_base.append(base)
		_tent_rot.append(rot)

	# 青绿幽光
	_light = OmniLight3D.new()
	_light.light_color = Color(0.2, 1.0, 0.8)
	_light.light_energy = 0.75
	_light.omni_range = 3.0
	_light.position = Vector3(0, 0.6, 0.3)
	_light.shadow_enabled = false
	gfx.add_child(_light)
	Game.tune_small_light(_light, 0.35, 3.2)


# ---------------------------------------------------------------- 行为

func _behave(delta: float) -> void:
	_t += delta
	state_t += delta
	bite_cd = maxf(bite_cd - delta, 0.0)
	_contact_cd = maxf(_contact_cd - delta, 0.0)
	_ensure_player()
	var d := dist_to_player()
	var dy := absf(player.global_position.y - global_position.y) \
		if player_alive() else 99.0

	match state:
		"patrol":
			velocity.x = move_toward(velocity.x, move_dir * PATROL_SPEED,
				10.0 * delta)
			if global_position.x > patrol_max:
				move_dir = -1.0
			elif global_position.x < patrol_min:
				move_dir = 1.0
			facing = move_dir
			if d < DETECT_RANGE and dy < 2.2:
				state = "chase"
				state_t = 0.0
		"chase":
			if not player_alive() or d > LOSE_RANGE:
				state = "patrol"
				state_t = 0.0
				velocity.x = move_toward(velocity.x, move_dir * PATROL_SPEED,
					6.0 * delta)
			else:
				var dir := signf(player.global_position.x - global_position.x)
				if dir != 0.0:
					move_dir = dir
				facing = move_dir
				# 不冲出巡逻范围：母体带范围，子体只在出生点附近小范围活动
				var nx := global_position.x + move_dir * 0.5
				if nx > patrol_min - 0.4 and nx < patrol_max + 0.4 \
					and dy < 2.2:
					velocity.x = move_toward(velocity.x, move_dir * CHASE_SPEED,
						14.0 * delta)
				else:
					velocity.x = move_toward(velocity.x, 0.0, 14.0 * delta)
				if d < BITE_RANGE and dy < 1.4 and bite_cd <= 0.0:
					state = "windup"
					state_t = 0.0
					velocity.x = 0.0
					Game.flash_meshes(gfx, Color(0.75, 1.0, 0.88), 0.12)
					Game.play_sfx("tide", -13.0, 1.7)
		"windup":
			velocity.x = move_toward(velocity.x, 0.0, 24.0 * delta)
			facing = move_dir
			if state_t >= BITE_WINDUP:
				state = "bite"
				state_t = 0.0
				bite_cd = BITE_CD
				_contact_cd = 0.0
				velocity.x = move_dir * 6.0
				velocity.y = 2.0
				Game.play_sfx("swing", -8.0, 1.2)
				var tw := gfx.create_tween()
				tw.tween_property(gfx, "scale", Vector3(1.3, 0.72, 1.0), 0.08)
				tw.tween_property(gfx, "scale", Vector3.ONE, 0.22)
		"bite":
			velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
			if d < BITE_RANGE + 0.25 and dy < 1.5 and _contact_cd <= 0.0 \
				and player_alive():
				_contact_cd = 0.5
				player.take_damage(touch_damage, global_position.x)
				Game.burst(get_parent(), player.global_position
					+ Vector3(0, 0.9, 0), Color(0.4, 1.0, 0.8), 10, 3.0,
					0.06, 0.3)
			if state_t >= BITE_TIME:
				state = "chase"
				state_t = 0.0
		_:
			state = "patrol"
			state_t = 0.0

	# 巡逻范围硬约束
	global_position.x = clampf(global_position.x, patrol_min, patrol_max)

	# 朝向
	var yaw := 0.0 if facing > 0.0 else PI
	gfx.rotation.y = lerp_angle(gfx.rotation.y, yaw, 12.0 * delta)

	# 双叶开合：前摇/扑咬时张开，平时呼吸
	var open := 0.0
	if state == "windup":
		open = 0.2
	elif state == "bite":
		open = 0.3
	if _lobe_l and _lobe_r:
		_lobe_l.position.x = lerpf(_lobe_l.position.x, -0.26 - open,
			12.0 * delta)
		_lobe_r.position.x = lerpf(_lobe_r.position.x, 0.26 + open,
			12.0 * delta)
		_lobe_l.rotation.z = sin(_t * 3.4) * 0.08 * (1.0 + open * 2.0)
		_lobe_r.rotation.z = -sin(_t * 3.4) * 0.08 * (1.0 + open * 2.0)
	# 触须摆动
	for i in _tentacles.size():
		var base := _tent_rot[i]
		_tentacles[i].rotation.z = base.z + sin(_t * 4.0 + i * 1.7) * 0.22
		_tentacles[i].rotation.x = sin(_t * 3.1 + i * 0.8) * 0.16
	# 身体起伏
	if _art:
		_art.position.y = absf(sin(_t * 5.0)) * 0.06
	# 核心呼吸 + 前摇增亮
	if _core_mat:
		var glow := 2.6 + sin(_t * 6.0) * 0.5 + open * 6.0
		_core_mat.emission_energy_multiplier = glow
	if _light:
		_light.light_energy = 0.6 + open * 2.0


func _ensure_player() -> void:
	## 关卡里敌人可能先于玩家 _ready：延迟补绑一次
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player


# ---------------------------------------------------------------- 分裂

func die() -> void:
	if dead:
		return
	if generation == 0:
		_split()
	super.die()


func _split() -> void:
	## 母体死亡：左右各裂出 1 只子体。子体用 generation=1 标记，不再分裂。
	## 子体照常走基类 die() → enemy_died，由竞技场统一计数。
	var par := get_parent()
	if par == null or not par.is_inside_tree():
		return
	var offsets := [-0.7, 0.7]
	for i in 2:
		var child := EnemyDivider.new()
		child.generation = 1            # 必须在 add_child 前设置（_setup 依赖它）
		child.position = position + Vector3(offsets[i], 0.15, 0.0)
		child.patrol_min = child.position.x - 1.4
		child.patrol_max = child.position.x + 1.4
		par.add_child(child)
		offspring.append(child)
		Game.burst(par, child.global_position + Vector3(0, 0.5, 0),
			Color(0.35, 1.0, 0.8), 14, 3.5, 0.07, 0.4)
	Game.play_sfx("tide", -6.0, 1.25)
