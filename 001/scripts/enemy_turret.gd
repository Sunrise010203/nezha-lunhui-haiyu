class_name EnemyTurret
extends EnemyBase
## 囚晶：固定悬浮的狱火晶体炮台。
## 每 2.2s 一轮：0.6s 预警（核心增亮放大 + 尖啸）→ 朝玩家连发 3 发弹幕
## （间隔 0.12s / 每发 9 伤害 / 速度 8）；玩家超出 18m 则停火待机。
## 完全固定：不重力、无碰撞推动、velocity 恒 0，位置由关卡摆放。

const CYCLE := 2.2              # 一轮总周期
const WARN_TIME := 0.6          # 预警
const SHOT_GAP := 0.12          # 连发间隔
const SHOT_COUNT := 3
const SHOT_DMG := 9.0
const SHOT_SPEED := 8.0
const SHOT_LIFE := 4.0

var fire_range := 18.0          # 超出此距离停火等待
var state := "idle"             # idle / warn / fire
var state_t := 0.0
var shots_left := 0
var _shot_t := 0.0
var _t := randf() * TAU
var _glow := 1.0
var _core: MeshInstance3D
var _core_mat: StandardMaterial3D
var _ring: MeshInstance3D
var _prisms: Array[MeshInstance3D] = []
var _prism_base: Array[Vector3] = []
var _light: OmniLight3D


# ---------------------------------------------------------------- 初始化

func _setup() -> void:
	uses_gravity = false
	collision_mask = 0
	max_hp = 90.0
	hp = max_hp
	touch_damage = 0.0
	knock_resist = 1.0           # 完全不被击退
	rim_color = Color(1.0, 0.35, 0.3, 0.9)   # 狱火红边
	add_hitbox(0.62, 1.5, 0.0)


func _build_gfx() -> void:
	# 3 根红色晶体（PrismMesh），绕核心呈放射状簇生
	var crystal_mat := Game.std_mat(Color(0.5, 0.07, 0.08, 0.82),
		Color(1.0, 0.16, 0.1), 1.3, 0.3, 0.1)
	crystal_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	crystal_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var prism := PrismMesh.new()
	prism.size = Vector3(0.24, 0.95, 0.24)
	for i in 3:
		var a := TAU * i / 3.0
		var base := Vector3(cos(a) * 0.3, 0.0, sin(a) * 0.26)
		# 向外倾斜：绕 z 轴按方位角摆开
		var rot := Vector3(rad_to_deg(sin(a)) * 0.35,
			rad_to_deg(a), rad_to_deg(cos(a)) * 0.3)
		var mi := Game.add_mesh(gfx, prism, crystal_mat, base, rot)
		_prisms.append(mi)
		_prism_base.append(rot)

	# 发光核心
	_core_mat = Game.std_mat(Color(1.0, 0.45, 0.3), Color(1.0, 0.28, 0.16),
		2.4, 0.2)
	var core := SphereMesh.new()
	core.radius = 0.24
	core.height = 0.48
	core.radial_segments = 16
	core.rings = 8
	_core = Game.add_mesh(gfx, core, _core_mat, Vector3(0, 0, 0))

	# 旋转狱火环（Torus）
	var ring_mat := Game.std_mat(Color(0.85, 0.18, 0.1),
		Color(1.0, 0.22, 0.08), 2.0, 0.4, 0.3)
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.albedo_color.a = 0.8
	var torus := TorusMesh.new()
	torus.inner_radius = 0.52
	torus.outer_radius = 0.63
	torus.ring_segments = 8
	torus.rings = 24
	_ring = Game.add_mesh(gfx, torus, ring_mat, Vector3(0, 0, 0),
		Vector3(72, 0, 0))

	# 悬浮微光
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.3, 0.15)
	_light.light_energy = 1.0
	_light.omni_range = 4.0
	_light.position = Vector3(0, 0, 0.4)
	_light.shadow_enabled = false
	gfx.add_child(_light)
	Game.tune_small_light(_light, 0.35, 3.6)

	# 狱火余烬
	var ember := GPUParticles3D.new()
	ember.amount = 10
	ember.lifetime = 0.7
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 60.0
	pm.initial_velocity_min = 0.15
	pm.initial_velocity_max = 0.5
	pm.gravity = Vector3(0, 0.8, 0)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.4
	pm.color = Color(1.0, 0.35, 0.12, 0.5)
	ember.process_material = pm
	var dm := SphereMesh.new()
	dm.radius = 0.04
	dm.height = 0.08
	dm.radial_segments = 4
	dm.rings = 2
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(1.0, 0.45, 0.2, 0.7)
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.material = dmat
	ember.draw_pass_1 = dm
	gfx.add_child(ember)


# ---------------------------------------------------------------- 行为

func _behave(delta: float) -> void:
	_t += delta
	state_t += delta
	# 固定炮台：速度永远为 0（基类 move_and_slide 因此不会移动它）
	velocity = Vector3.ZERO
	_ensure_player()
	var in_range := player_alive() and dist_to_player() <= fire_range

	var glow_target := 1.0 + sin(_t * 2.4) * 0.25
	match state:
		"idle":
			# 玩家不在射程内：停火等待，周期计时归零
			if not in_range:
				state_t = 0.0
			elif state_t >= CYCLE - WARN_TIME - SHOT_GAP * (SHOT_COUNT - 1):
				_enter_warn()
		"warn":
			if not in_range:
				# 预警中玩家离开：取消这一轮
				state = "idle"
				state_t = 0.0
				gfx.scale = gfx.scale.lerp(Vector3.ONE, 14.0 * delta)
			else:
				var p := clampf(state_t / WARN_TIME, 0.0, 1.0)
				glow_target = 1.0 + p * 5.5
				gfx.scale = gfx.scale.lerp(Vector3.ONE * (1.0 + 0.14 * p),
					16.0 * delta)
				if state_t >= WARN_TIME:
					_enter_fire()
		"fire":
			glow_target = 3.4
			if not player_alive():
				state = "idle"
				state_t = 0.0
				shots_left = 0
			elif shots_left > 0:
				_shot_t += delta
				if _shot_t >= 0.0:
					_shoot()
					shots_left -= 1
					_shot_t = -SHOT_GAP
			else:
				state = "idle"
				state_t = 0.0
				gfx.scale = gfx.scale.lerp(Vector3.ONE, 14.0 * delta)
		_:
			state = "idle"
			state_t = 0.0

	# 核心明暗（预警时越来越亮、越来越大）
	_glow = lerpf(_glow, glow_target, 10.0 * delta)
	if _core_mat:
		_core_mat.emission_energy_multiplier = 1.6 + _glow * 1.8
	if _light:
		_light.light_energy = 0.7 + _glow * 0.8

	# 晶簇缓慢自转、环旋转、核心脉动
	gfx.rotation.y += delta * 0.4
	if _ring:
		_ring.rotation.z += delta * 1.5
		_ring.rotation.x = deg_to_rad(72.0 + sin(_t * 1.2) * 6.0)
	for i in _prisms.size():
		var rb := _prism_base[i]
		_prisms[i].rotation.x = deg_to_rad(rb.x) + sin(_t * 1.5 + i * 2.0) * 0.1
	if _core:
		var cs := 1.0 + clampf(_glow - 1.0, 0.0, 5.0) * 0.09
		_core.scale = Vector3.ONE * cs
	# 悬浮轻微起伏（只动视觉，不动物理位置）
	gfx.position.y = sin(_t * 1.6) * 0.12


func _ensure_player() -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player


func _enter_warn() -> void:
	state = "warn"
	state_t = 0.0
	Game.play_sfx("shoot", -12.0, 1.4)
	Game.burst(get_parent(), global_position, Color(1.0, 0.3, 0.2), 12,
		2.5, 0.06, 0.35)


func _enter_fire() -> void:
	state = "fire"
	state_t = 0.0
	shots_left = SHOT_COUNT
	_shot_t = 0.0
	Game.play_sfx("shoot", -10.0, 1.15)
	gfx.scale = Vector3.ONE


func _shoot() -> void:
	if not player_alive():
		return
	var origin := global_position
	var target := player.global_position + Vector3(0, 0.9, 0)
	if target.distance_to(origin) < 0.05:
		return
	var proj := Projectile.new()
	proj.dmg = SHOT_DMG
	proj.tint = Color(1.0, 0.32, 0.2)
	proj.life = SHOT_LIFE
	proj.vel = (target - origin).normalized() * SHOT_SPEED
	proj.position = origin
	get_parent().add_child(proj)
	Game.burst(get_parent(), origin, proj.tint, 6, 2.0, 0.05, 0.25)
	Game.play_sfx("shoot", -16.0, 1.6)
