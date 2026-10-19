class_name EnemyWraith
extends EnemyBase
## 潮魇：悬浮幽体。慢飘 → 预警蓄势 → 高速突进 → 硬直，循环往复。
## 突进是主要威胁：预警 0.55s 给玩家反应窗口，冲刺 0.35s @18m/s。

# ---- 巡逻范围（关卡接线时写入；默认以出生点 ±8）
var patrol_min := 0.0
var patrol_max := 0.0

var spawn_y := 0.0
var state := "idle"
var state_t := 0.0
var facing := 1.0

const IDLE_SPEED := 2.0        # 悬浮漂移速度
const IDLE_MIN := 0.8          # idle 时长下限
const IDLE_MAX := 1.2
const TELE_TIME := 0.55        # 预警
const DASH_TIME := 0.35        # 冲刺
const DASH_SPEED := 18.0
const RECOVER_TIME := 1.2      # 硬直
const HOVER_AMP := 0.25        # 上下浮动幅度
const HOVER_FREQ := 2.0

var _t := 0.0
var _idle_dur := 1.0
var _dash_dir := 1.0
var _dash_hit := false
var _glow := 1.4

var _body_mat: StandardMaterial3D
var _eye_mat: StandardMaterial3D
var _ribbons: Array[MeshInstance3D] = []
var _ribbon_rot: Array[Vector3] = []
var _light: OmniLight3D


# ---------------------------------------------------------------- 初始化

func _setup() -> void:
	max_hp = 50.0
	hp = max_hp
	touch_damage = 16.0
	knock_resist = 0.1
	uses_gravity = false
	collision_mask = 0
	rim_color = Color(0.65, 0.35, 1.0, 0.9)   # 紫边：区别于爬行者的青边
	add_hitbox(0.5, 1.05, 0.45)
	spawn_y = global_position.y
	if patrol_max <= patrol_min:
		patrol_min = global_position.x - 8.0
		patrol_max = global_position.x + 8.0
	_idle_dur = randf_range(IDLE_MIN, IDLE_MAX)


func _build_gfx() -> void:
	# 半透明紫色幽体球
	_body_mat = Game.std_mat(Color(0.34, 0.14, 0.58, 0.62),
		Color(0.5, 0.2, 0.9), 1.4, 0.3)
	_body_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var body := SphereMesh.new()
	body.radius = 0.48
	body.height = 0.96
	body.radial_segments = 18
	body.rings = 9
	Game.add_mesh(gfx, body, _body_mat, Vector3(0, 0.45, 0),
		Vector3.ZERO, Vector3(1.15, 0.95, 1.0))

	# 体内幽核
	var core_mat := Game.std_mat(Color(0.72, 0.42, 1.0, 0.8),
		Color(0.8, 0.45, 1.0), 2.4, 0.2)
	core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var core := SphereMesh.new()
	core.radius = 0.22
	core.height = 0.44
	Game.add_mesh(gfx, core, core_mat, Vector3(-0.05, 0.45, 0),
		Vector3.ZERO, Vector3(0.8, 1.15, 0.8))

	# 两只发光眼（朝 +x 正面）
	_eye_mat = Game.std_mat(Color(0.95, 0.85, 1.0), Color(0.8, 0.9, 1.0),
		3.2, 0.1)
	var eye := SphereMesh.new()
	eye.radius = 0.075
	eye.height = 0.15
	Game.add_mesh(gfx, eye, _eye_mat, Vector3(0.5, 0.55, 0.17))
	Game.add_mesh(gfx, eye, _eye_mat, Vector3(0.5, 0.55, -0.17))

	# 4 条飘带（BoxMesh，拖在 -x 后方）
	var ribbon_mat := Game.std_mat(Color(0.4, 0.18, 0.66, 0.68),
		Color(0.55, 0.25, 0.9), 1.1, 0.3)
	ribbon_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var ribbon := BoxMesh.new()
	ribbon.size = Vector3(0.95, 0.11, 0.05)
	for i in 4:
		var z := 0.2 if i % 2 == 0 else -0.2
		var pos := Vector3(-0.52 - 0.04 * i, 0.62 - 0.2 * i, z)
		var rot := Vector3(0, 0, 16 - i * 9)
		var mi := Game.add_mesh(gfx, ribbon, ribbon_mat, pos, rot)
		_ribbons.append(mi)
		_ribbon_rot.append(rot)

	# 幽光
	_light = OmniLight3D.new()
	_light.light_color = Color(0.55, 0.25, 1.0)
	_light.light_energy = 1.0
	_light.omni_range = 3.6
	_light.position = Vector3(0, 0.45, 0.3)
	_light.shadow_enabled = false
	gfx.add_child(_light)


# ---------------------------------------------------------------- 行为

func _behave(delta: float) -> void:
	_t += delta
	state_t += delta
	_ensure_player()

	# 悬浮：y = spawn_y + sin(t*2)*0.25
	var hover_target := spawn_y + sin(_t * HOVER_FREQ) * HOVER_AMP
	velocity.y = clampf((hover_target - global_position.y) * 6.0, -4.0, 4.0)

	match state:
		"idle":
			_do_idle(delta)
			_update_glow(delta, 1.4)
			gfx.scale = gfx.scale.lerp(Vector3.ONE, 8.0 * delta)
			if state_t >= _idle_dur:
				_enter_tele()
		"tele":
			velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
			_update_facing()
			var p := clampf(state_t / TELE_TIME, 0.0, 1.0)
			_update_glow(delta, 1.4 + 2.8 * p)
			gfx.scale = gfx.scale.lerp(Vector3.ONE * (1.0 + 0.28 * p),
				14.0 * delta)
			if state_t >= TELE_TIME:
				_enter_dash()
		"dash":
			velocity.x = _dash_dir * DASH_SPEED
			# 不冲出巡逻范围（不闯 Boss 场 / 关底）
			var nx := global_position.x + velocity.x * delta
			if (_dash_dir < 0.0 and nx <= patrol_min) \
				or (_dash_dir > 0.0 and nx >= patrol_max):
				velocity.x = 0.0
			facing = _dash_dir
			_update_glow(delta, 3.2)
			gfx.scale = gfx.scale.lerp(Vector3(1.32, 0.82, 1.04), 16.0 * delta)
			_check_dash_hit()
			if state_t >= DASH_TIME:
				_enter_recover()
		"recover":
			velocity.x = move_toward(velocity.x, 0.0, 16.0 * delta)
			_update_glow(delta, 1.2)
			gfx.scale = gfx.scale.lerp(Vector3.ONE, 6.0 * delta)
			if state_t >= RECOVER_TIME:
				state = "idle"
				state_t = 0.0
				_idle_dur = randf_range(IDLE_MIN, IDLE_MAX)
		_:
			state = "idle"
			state_t = 0.0

	# 巡逻范围硬约束
	global_position.x = clampf(global_position.x, patrol_min, patrol_max)

	# 朝向：淡入转向
	var yaw := 0.0 if facing > 0.0 else PI
	gfx.rotation.y = lerp_angle(gfx.rotation.y, yaw, 10.0 * delta)
	# 飘带摆动 / 冲刺时拉长
	var dash_amt := 1.0 if state == "dash" else 0.0
	for i in _ribbons.size():
		var r := _ribbons[i]
		var base := _ribbon_rot[i]
		r.rotation.z = base.z + sin(_t * 2.6 + i * 1.4) * 0.2
		r.rotation.x = base.x + cos(_t * 2.1 + i * 0.9) * 0.18
		r.scale = Vector3(1.0 + 0.55 * dash_amt, 1.0, 1.0)


func _do_idle(delta: float) -> void:
	var want := 0.0
	if player_alive():
		var dx := player.global_position.x - global_position.x
		if absf(dx) > 0.6:
			want = signf(dx) * IDLE_SPEED
			facing = signf(dx)
	# 不越界：到达边界就停
	var nx := global_position.x + want * delta
	if nx < patrol_min or nx > patrol_max:
		want = 0.0
	velocity.x = move_toward(velocity.x, want, 8.0 * delta)


func _update_facing() -> void:
	if player_alive():
		var dx := player.global_position.x - global_position.x
		if absf(dx) > 0.05:
			facing = signf(dx)


func _enter_tele() -> void:
	state = "tele"
	state_t = 0.0
	velocity.x = 0.0
	_update_facing()
	Game.play_sfx("shoot", -7.0, 1.35)
	Game.burst(get_parent(), global_position + Vector3(0, 0.45, 0),
		Color(0.65, 0.35, 1.0), 12, 2.6, 0.06, 0.4)


func _enter_dash() -> void:
	state = "dash"
	state_t = 0.0
	_dash_hit = false
	_update_facing()
	_dash_dir = facing
	velocity.x = _dash_dir * DASH_SPEED
	Game.play_sfx("swing", -6.0, 0.75)
	Game.burst(get_parent(), global_position + Vector3(0, 0.45, 0),
		Color(0.6, 0.3, 1.0), 16, 4.5, 0.07, 0.35)


func _enter_recover() -> void:
	state = "recover"
	state_t = 0.0
	velocity.x *= 0.2


func _check_dash_hit() -> void:
	## 冲刺接触伤害：每轮只结算一次
	if _dash_hit or not player_alive():
		return
	var dx := absf(player.global_position.x - global_position.x)
	var dy := absf(player.global_position.y + 0.9
		- (global_position.y + 0.45))
	if dx < 1.15 and dy < 1.3:
		_dash_hit = true
		player.take_damage(touch_damage, global_position.x)
		Game.shake(0.22)
		Game.burst(get_parent(), player.global_position
			+ Vector3(0, 0.9, 0), Color(0.8, 0.4, 1.0), 14, 4.0, 0.07, 0.4)


func _update_glow(delta: float, target: float) -> void:
	_glow = lerpf(_glow, target, 10.0 * delta)
	if _body_mat:
		_body_mat.emission_energy_multiplier = _glow
	if _eye_mat:
		_eye_mat.emission_energy_multiplier = 2.0 + _glow * 0.6
	if _light:
		_light.light_energy = 0.55 + _glow * 0.55


func _ensure_player() -> void:
	## 关卡里敌人可能先于玩家 _ready：延迟补绑一次
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player


func _on_hurt() -> void:
	# 受击不打断循环，只是略微缩短预警/硬直，让连击手感更顺
	if state == "recover":
		state_t = maxf(state_t, RECOVER_TIME - 0.25)
