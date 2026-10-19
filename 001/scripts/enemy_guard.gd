class_name EnemyGuard
extends EnemyBase
## 狱卒：铁灰重甲盾卫。
## 缓慢逼近（2.2m/s）→ 0.55s 举盾前摇 → 盾撞短突进（6m/s 持续 0.3s / 18 伤害 / 2.5s 冷却）。
## 举盾免伤：正面（玩家在 facing 一侧）的普通攻击只吃 25% 伤害并打出金属音；
## 重击或从背后打则全额。facing 只在逼近时跟随玩家，前摇/盾撞/硬直期间锁定，
## 因此玩家可以冲刺绕背打真伤。

const APPROACH_SPEED := 2.2
const TELE_TIME := 0.55         # 举盾前摇
const BASH_TIME := 0.3          # 盾撞突进时长
const BASH_SPEED := 6.0
const BASH_CD := 2.5
const BASH_RANGE := 3.0         # 进入盾撞的距离
const BASH_HIT_R := 1.5
const RECOVER_TIME := 0.45
const PATROL_SPEED := 1.2

var patrol_min := 0.0
var patrol_max := 0.0
var state := "approach"
var state_t := 0.0
var facing := 1.0
var bash_cd := 0.0
var _bash_hit := false
var _t := 0.0
var _shield_arm: Node3D
var _shield_red_mat: StandardMaterial3D
var _shield_lift := 0.0
var _light: OmniLight3D


# ---------------------------------------------------------------- 初始化

func _setup() -> void:
	uses_gravity = true
	max_hp = 95.0
	hp = max_hp
	touch_damage = 18.0
	knock_resist = 0.75
	rim_color = Color(1.0, 0.45, 0.25, 0.9)   # 狱火橙边
	add_hitbox(0.5, 1.7, 0.85)
	if patrol_max <= patrol_min:
		patrol_min = global_position.x - 3.0
		patrol_max = global_position.x + 3.0


func _build_gfx() -> void:
	var iron := Game.std_mat(Color(0.27, 0.29, 0.33), Color(0.04, 0.05, 0.07),
		0.5, 0.72, 0.55)
	var dark := Game.std_mat(Color(0.13, 0.14, 0.17), Color(0.02, 0.02, 0.03),
		0.5, 0.85, 0.4)
	var trim := Game.std_mat(Color(0.5, 0.27, 0.13), Color(0.3, 0.1, 0.03),
		0.8, 0.55, 0.5)

	# 双腿
	var leg := BoxMesh.new()
	leg.size = Vector3(0.26, 0.55, 0.3)
	for z in [-0.17, 0.17]:
		Game.add_mesh(gfx, leg, dark, Vector3(0, 0.28, z))
	# 护腰
	var waist := BoxMesh.new()
	waist.size = Vector3(0.56, 0.22, 0.5)
	Game.add_mesh(gfx, waist, trim, Vector3(0, 0.58, 0))
	# 躯干重甲
	var torso := BoxMesh.new()
	torso.size = Vector3(0.62, 0.82, 0.54)
	Game.add_mesh(gfx, torso, iron, Vector3(0, 0.98, 0))
	# 胸甲中缝
	var chest := BoxMesh.new()
	chest.size = Vector3(0.1, 0.66, 0.58)
	Game.add_mesh(gfx, chest, trim, Vector3(0.3, 0.98, 0))
	# 肩甲
	var pad := BoxMesh.new()
	pad.size = Vector3(0.36, 0.26, 0.3)
	for z in [-0.32, 0.32]:
		Game.add_mesh(gfx, pad, dark, Vector3(0, 1.33, z))
	# 头盔
	var helm := BoxMesh.new()
	helm.size = Vector3(0.42, 0.4, 0.42)
	Game.add_mesh(gfx, helm, iron, Vector3(0.01, 1.55, 0))
	# 面甲缝
	var slit := BoxMesh.new()
	slit.size = Vector3(0.07, 0.09, 0.34)
	Game.add_mesh(gfx, slit, dark, Vector3(0.22, 1.53, 0))
	# 狱卒红眼
	var eye_mat := Game.std_mat(Color(1.0, 0.25, 0.12),
		Color(1.0, 0.18, 0.08), 3.0, 0.2)
	var eye := SphereMesh.new()
	eye.radius = 0.05
	eye.height = 0.1
	Game.add_mesh(gfx, eye, eye_mat, Vector3(0.23, 1.56, 0.1))
	Game.add_mesh(gfx, eye, eye_mat, Vector3(0.23, 1.56, -0.1))

	# 左手大盾（+x 为正面）：红边包铁板
	_shield_arm = Node3D.new()
	_shield_arm.name = "shield_arm"
	gfx.add_child(_shield_arm)
	_shield_red_mat = Game.std_mat(Color(0.45, 0.07, 0.03),
		Color(1.0, 0.2, 0.05), 1.6, 0.6, 0.2)
	var edge := BoxMesh.new()
	edge.size = Vector3(0.98, 1.42, 0.14)
	Game.add_mesh(_shield_arm, edge, _shield_red_mat, Vector3(0.36, 1.02, 0))
	var plate := BoxMesh.new()
	plate.size = Vector3(0.88, 1.3, 0.2)
	Game.add_mesh(_shield_arm, plate, iron, Vector3(0.36, 1.02, 0))
	# 盾心狱火核
	var boss := BoxMesh.new()
	boss.size = Vector3(0.22, 0.22, 0.08)
	Game.add_mesh(_shield_arm, boss, _shield_red_mat, Vector3(0.36, 1.02, 0.13))
	# 盾面辉光
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.35, 0.12)
	_light.light_energy = 0.8
	_light.omni_range = 3.0
	_light.position = Vector3(0.45, 1.02, 0.35)
	_light.shadow_enabled = false
	_shield_arm.add_child(_light)
	Game.tune_small_light(_light, 0.35, 3.2)
	# 盾牌上的狱火粒子
	var ember := GPUParticles3D.new()
	ember.amount = 8
	ember.lifetime = 0.5
	ember.position = Vector3(0.36, 1.02, 0.2)
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 35.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.7
	pm.gravity = Vector3(0, 1.2, 0)
	pm.color = Color(1.0, 0.35, 0.1, 0.55)
	ember.process_material = pm
	var dm := SphereMesh.new()
	dm.radius = 0.035
	dm.height = 0.07
	dm.radial_segments = 4
	dm.rings = 2
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(1.0, 0.4, 0.15, 0.7)
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.material = dmat
	ember.draw_pass_1 = dm
	_shield_arm.add_child(ember)


# ---------------------------------------------------------------- 盾牌免伤

func take_damage(dmg: float, dir: float, heavy := false) -> void:
	if dead:
		return
	if not heavy and _is_front_attack(dir):
		# 举盾格挡：正面普攻只吃 35%，金属音 + 火花
		Game.play_sfx("hit", -8.0, 0.7)
		_shield_spark()
		super.take_damage(dmg * 0.35, dir, heavy)
		return
	super.take_damage(dmg, dir, heavy)


func _is_front_attack(dir: float) -> bool:
	## dir 是击退方向（攻击者 → 狱卒）。玩家在 facing 一侧时 dir 与 facing 反向，
	## 即盾面正对攻击者：dir * facing < 0 判定为正面。
	if not is_zero_approx(dir):
		return dir * facing < 0.0
	# 兜底：dir 缺省时按玩家实际方位判断（玩家在 facing 侧即正面）
	if player_alive():
		return signf(player.global_position.x - global_position.x) == facing
	return false


func _shield_spark() -> void:
	var p := global_position + Vector3(facing * 0.55, 1.0, 0)
	Game.burst(get_parent(), p, Color(1.0, 0.6, 0.2), 10, 3.2, 0.05, 0.3)
	if _shield_red_mat:
		_shield_red_mat.emission_energy_multiplier = 4.5


# ---------------------------------------------------------------- 行为

func _behave(delta: float) -> void:
	_t += delta
	state_t += delta
	bash_cd = maxf(bash_cd - delta, 0.0)
	_ensure_player()
	var d := dist_to_player()
	var dy := absf(player.global_position.y - global_position.y) \
		if player_alive() else 99.0

	match state:
		"approach":
			_face_player()
			var want := 0.0
			if player_alive() and dy < 2.4:
				if d > 1.6:
					want = facing * APPROACH_SPEED
			else:
				# 无目标时在巡逻范围内缓慢踱步
				if global_position.x > patrol_max:
					facing = -1.0
				elif global_position.x < patrol_min:
					facing = 1.0
				want = facing * PATROL_SPEED
			# 不越界
			if want != 0.0:
				var nx := global_position.x + signf(want) * 0.4
				if nx < patrol_min or nx > patrol_max:
					want = 0.0
			velocity.x = move_toward(velocity.x, want, 8.0 * delta)
			if player_alive() and d < BASH_RANGE and dy < 2.0 \
				and bash_cd <= 0.0:
				_enter_tele()
		"tele":
			velocity.x = move_toward(velocity.x, 0.0, 26.0 * delta)
			if state_t >= TELE_TIME:
				_enter_bash()
		"bash":
			velocity.x = facing * BASH_SPEED
			# 不冲出巡逻边界
			var nx2 := global_position.x + velocity.x * delta
			if (facing < 0.0 and nx2 <= patrol_min) \
				or (facing > 0.0 and nx2 >= patrol_max):
				velocity.x = 0.0
			if not _bash_hit and player_alive():
				var pdx := absf(player.global_position.x - global_position.x)
				var pdy := absf(player.global_position.y + 0.9
					- (global_position.y + 0.85))
				if pdx < BASH_HIT_R and pdy < 1.4:
					_bash_hit = true
					player.take_damage(touch_damage, global_position.x)
					Game.shake(0.18)
					Game.burst(get_parent(), player.global_position
						+ Vector3(0, 0.9, 0), Color(1.0, 0.45, 0.15), 14,
						4.0, 0.07, 0.4)
			if state_t >= BASH_TIME:
				state = "recover"
				state_t = 0.0
				velocity.x *= 0.3
		"recover":
			velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
			if state_t >= RECOVER_TIME:
				state = "approach"
				state_t = 0.0
		_:
			state = "approach"
			state_t = 0.0

	global_position.x = clampf(global_position.x, patrol_min, patrol_max)

	# 朝向
	var yaw := 0.0 if facing > 0.0 else PI
	gfx.rotation.y = lerp_angle(gfx.rotation.y, yaw, 9.0 * delta)

	# 盾牌：平时举在身前，前摇再抬高顶出去
	var lift_target := 1.0 if state == "tele" else \
		(0.7 if state == "bash" else 0.0)
	_shield_lift = lerpf(_shield_lift, lift_target, 12.0 * delta)
	if _shield_arm:
		_shield_arm.position = Vector3(0.06 + 0.2 * _shield_lift,
			0.05 * _shield_lift, 0.0)
		_shield_arm.rotation.z = -0.16 * _shield_lift
	if _shield_red_mat:
		var glow := 1.4 + _shield_lift * 2.2
		if state == "bash":
			glow = 3.4
		_shield_red_mat.emission_energy_multiplier = lerpf(
			_shield_red_mat.emission_energy_multiplier, glow, 10.0 * delta)
	if _light:
		_light.light_energy = lerpf(_light.light_energy,
			0.7 + 1.4 * _shield_lift, 10.0 * delta)
	# 沉重呼吸
	gfx.position.y = sin(_t * 2.2) * 0.015


func _face_player() -> void:
	if not player_alive():
		return
	var dx := player.global_position.x - global_position.x
	if absf(dx) > 0.2:
		facing = signf(dx)


func _enter_tele() -> void:
	state = "tele"
	state_t = 0.0
	velocity.x = 0.0
	Game.play_sfx("swing", -10.0, 0.55)
	Game.flash_meshes(_shield_arm, Color(1.0, 0.55, 0.3), 0.12)
	Game.burst(get_parent(), global_position + Vector3(facing * 0.6, 1.0, 0),
		Color(1.0, 0.4, 0.15), 10, 2.5, 0.06, 0.3)


func _enter_bash() -> void:
	state = "bash"
	state_t = 0.0
	bash_cd = BASH_CD
	_bash_hit = false
	velocity.x = facing * BASH_SPEED
	Game.play_sfx("hit", -6.0, 0.75)
	Game.burst(get_parent(), global_position + Vector3(facing * 0.7, 0.9, 0),
		Color(1.0, 0.4, 0.12), 10, 3.0, 0.06, 0.3)


func _ensure_player() -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player


func _on_hurt() -> void:
	# 受击时盾牌火光一颤（数值形态不被打断，体现"抗打"）
	if _shield_red_mat:
		_shield_red_mat.emission_energy_multiplier = 3.6
