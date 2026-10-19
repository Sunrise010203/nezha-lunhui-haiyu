class_name EnemyBomber
extends EnemyBase
## 渊爆水母：缓慢追踪玩家，贴近（或被打死）后点燃引信，0.45s 后自爆。
## 爆炸只伤玩家，不伤其它敌人；本体触伤为 0，全部威胁集中在爆炸上。

var hover_y := 0.0
var state := "chase"
var state_t := 0.0

const FUSE_RADIUS := 1.8       # 进入引信的距离
const FUSE_TIME := 0.45        # 引信时长
const BLAST_RADIUS := 2.4      # 爆炸伤害半径
const BLAST_DAMAGE := 18.0
const CHASE_SPEED := 1.8
const HOVER_LIMIT := 2.5       # 追随玩家高度上限 ±2.5

var _t := 0.0
var _exploded := false
var _bell_mat: StandardMaterial3D
var _core_mat: StandardMaterial3D
var _base_bell := Color(0.45, 0.14, 0.1, 0.8)
var _tentacles: Array[MeshInstance3D] = []
var _tent_rot: Array[Vector3] = []
var _light: OmniLight3D


# ---------------------------------------------------------------- 初始化

func _setup() -> void:
	max_hp = 35.0
	hp = max_hp
	touch_damage = 0.0          # 只有爆炸伤害
	knock_resist = 0.0
	uses_gravity = false
	collision_mask = 0
	rim_color = Color(1.0, 0.55, 0.3, 0.9)   # 橙红边：警示自爆
	add_hitbox(0.55, 1.0, 0.2)
	hover_y = global_position.y


func _build_gfx() -> void:
	# 半透明橙红伞状钟体
	_bell_mat = Game.std_mat(_base_bell, Color(0.9, 0.3, 0.12), 1.2, 0.25)
	_bell_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var bell := SphereMesh.new()
	bell.radius = 0.55
	bell.height = 1.1
	bell.radial_segments = 18
	bell.rings = 9
	Game.add_mesh(gfx, bell, _bell_mat, Vector3(0, 0.38, 0),
		Vector3.ZERO, Vector3(1.1, 0.7, 1.1))

	# 内核发光（自爆能量的来源）
	_core_mat = Game.std_mat(Color(1.0, 0.7, 0.3), Color(1.0, 0.45, 0.15),
		2.4, 0.2)
	var core := SphereMesh.new()
	core.radius = 0.2
	core.height = 0.4
	Game.add_mesh(gfx, core, _core_mat, Vector3(0, 0.3, 0))

	# 下垂触须
	var tent_mat := Game.std_mat(Color(0.5, 0.18, 0.14, 0.85),
		Color(0.7, 0.25, 0.1), 0.8, 0.4)
	tent_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var tent := CylinderMesh.new()
	tent.top_radius = 0.055
	tent.bottom_radius = 0.018
	tent.height = 1.0
	for i in 5:
		var a := TAU * i / 5.0
		var pos := Vector3(cos(a) * 0.3, -0.28, sin(a) * 0.3)
		var rot := Vector3(0, 0, 0)
		var mi := Game.add_mesh(gfx, tent, tent_mat, pos, rot)
		_tentacles.append(mi)
		_tent_rot.append(rot)

	# 暖光
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.55, 0.3)
	_light.light_energy = 1.0
	_light.omni_range = 3.6
	_light.position = Vector3(0, 0.3, 0.3)
	_light.shadow_enabled = false
	gfx.add_child(_light)


# ---------------------------------------------------------------- 行为

func _behave(delta: float) -> void:
	_t += delta
	state_t += delta
	_ensure_player()
	_float(delta)

	match state:
		"chase":
			_do_chase(delta)
			if hp <= 0.0:
				_enter_fuse()
			elif player_alive() and dist_to_player() < FUSE_RADIUS:
				_enter_fuse()
		"fuse":
			velocity.x = move_toward(velocity.x, 0.0, 24.0 * delta)
			var p := clampf(state_t / FUSE_TIME, 0.0, 1.0)
			var pulse := 1.0 + p * 0.45 + sin(_t * 46.0) * 0.035 * p
			gfx.scale = Vector3.ONE * pulse
			_set_heat(p)
			if state_t >= FUSE_TIME:
				_explode()
		"boom":
			velocity.x = move_toward(velocity.x, 0.0, 24.0 * delta)
		_:
			state = "chase"
			state_t = 0.0
			gfx.scale = Vector3.ONE

	_animate(delta)


func _float(delta: float) -> void:
	# 悬浮：高度朝玩家靠拢，但限制在 spawn ±2.5
	var target_y := hover_y
	if player_alive():
		target_y = clampf(player.global_position.y + 1.0,
			hover_y - HOVER_LIMIT, hover_y + HOVER_LIMIT)
	var bob := sin(_t * 1.7) * 0.16
	velocity.y = clampf((target_y + bob - global_position.y) * 5.0, -4.0, 4.0)


func _do_chase(delta: float) -> void:
	if not player_alive():
		velocity.x = move_toward(velocity.x, 0.0, 5.0 * delta)
		return
	var dx := player.global_position.x - global_position.x
	velocity.x = move_toward(velocity.x, signf(dx) * CHASE_SPEED,
		6.0 * delta)


func _enter_fuse() -> void:
	if dead or state == "fuse" or state == "boom":
		return
	state = "fuse"
	state_t = 0.0
	velocity.x = 0.0
	# 引信提示音（复用 shoot 短促音，升调加快节奏感）
	Game.play_sfx("shoot", -6.0, 0.72)
	Game.shake(0.12)
	Game.burst(get_parent(), global_position + Vector3(0, 0.3, 0),
		Color(1.0, 0.6, 0.25), 8, 2.0, 0.05, 0.3)


func _explode() -> void:
	state = "boom"
	_exploded = true
	var p := global_position + Vector3(0, 0.35, 0)
	# 大爆炸（三层：橙火 / 高光 / 暗红余烬）
	Game.burst(get_parent(), p, Color(1.0, 0.5, 0.15), 60, 9.0, 0.16, 0.9)
	Game.burst(get_parent(), p, Color(1.0, 0.85, 0.4), 30, 6.5, 0.1, 0.7)
	Game.burst(get_parent(), p, Color(0.7, 0.2, 0.1), 24, 4.5, 0.12, 0.8)
	Game.play_sfx("roar", -5.0, 0.7)
	Game.shake(0.45)
	# 只伤玩家（不遍历其它敌人）
	if player_alive():
		var center := player.global_position + Vector3(0, 0.9, 0)
		if global_position.distance_to(center) <= BLAST_RADIUS:
			player.take_damage(BLAST_DAMAGE, global_position.x)
	super.die()


func die() -> void:
	if dead:
		return
	# 契约：血量归零时也必须先走引信自爆，再真正死亡
	if not _exploded:
		if hp <= 0.0:
			hp = 0.0
		_enter_fuse()
		return
	super.die()


func _set_heat(p: float) -> void:
	if _bell_mat:
		_bell_mat.albedo_color = _base_bell.lerp(
			Color(1.0, 0.22, 0.12, 0.92), p)
		_bell_mat.emission_energy_multiplier = 1.2 + p * 4.5
	if _core_mat:
		_core_mat.emission_energy_multiplier = 2.4 + p * 7.0
	if _light:
		_light.light_color = Color(1.0, 0.55, 0.3).lerp(
			Color(1.0, 0.2, 0.1), p)
		_light.light_energy = 1.0 + p * 3.5


func _animate(delta: float) -> void:
	# 触须摆动：引信阶段蜷曲抽动
	var heat := clampf(state_t / FUSE_TIME, 0.0, 1.0) \
		if state == "fuse" else 0.0
	for i in _tentacles.size():
		var tp := _tentacles[i]
		var base := _tent_rot[i]
		var spd := 2.2 + heat * 7.0
		var amp := 0.2 + heat * 0.35
		tp.rotation.x = base.x + sin(_t * spd + i * 1.3) * amp
		tp.rotation.z = base.z + cos(_t * spd * 0.8 + i * 0.9) * amp
	# 追踪阶段轻微左右摇摆
	if state != "fuse":
		gfx.rotation.z = lerp_angle(gfx.rotation.z,
			sin(_t * 1.5) * 0.06, 6.0 * delta)


func _ensure_player() -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player
