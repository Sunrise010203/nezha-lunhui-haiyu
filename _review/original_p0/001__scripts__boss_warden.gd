class_name BossWarden
extends EnemyBase
## 棘狱守卫：龙宫深狱的走地重甲狱卒（第二章 Boss）
## ------------------------------------------------------------------
## 招式（每个都有 0.5~0.9s 可读预警：地面红环 / 冲锋轨道 / 体表发光）：
##   铁棘冲锋 —— 锁向玩家后沿地面横冲，撞到即重伤害；撞墙后有 0.9s 硬直
##   裂狱砸地 —— 抬起上身蓄力，砸地放双向地面冲击波（可跳跃躲）
##   狱棘弹幕 —— 胸前核心亮起后扇形射出棘刺
##   召唤残兵 —— 咆哮召出狱卒（通过 summon_requested 交给关卡生成）
## 二阶段规则变化（不只是数值）：
##   1) 冲锋变成二连突进（第一段撞墙后立刻反向再冲）
##   2) 弹幕从「单次 5 发扇形」变成「三连 7 发宽扇形」
##   3) 砸地追加第二波冲击波
##   4) 召唤数量 2 → 3
## ------------------------------------------------------------------
## 契约与 BossMaw 完全一致：信号 boss_hp_changed / summon_requested /
## boss_defeated，方法 activate() / reset_fight() / take_damage(dmg, dir, heavy)。
## 外观三种模式（专属模型 / 立绘 / 程序化重甲）：资源缺失时走程序化网格，
## 因此 spr / model / body_mat 等引用在不同模式下都可能为 null，
## 所有外观读写必须逐个判空（第一章 Boss 就崩在 reset_fight 的 else 分支）。

signal boss_hp_changed(hp: float, max_hp: float)
signal summon_requested(count: int)
signal boss_defeated

const SPR_H := 3.9
const CHARGE_SPEED := 15.0
const TELEGRAPH_CHARGE := 0.7
const TELEGRAPH_CHARGE_FAST := 0.5
const TELEGRAPH_SLAM := 0.75
const TELEGRAPH_BARRAGE := 0.6
const TELEGRAPH_SUMMON := 0.8
const CONTACT_DMG := 6.0

const C_IRON := Color(0.30, 0.17, 0.14)
const C_EMBER := Color(1.0, 0.42, 0.12)
const C_CORE := Color(1.0, 0.62, 0.2)
const MODEL_TINT_P1 := Color(0.80, 0.54, 0.50)
const MODEL_TINT_P2 := Color(1.30, 0.60, 0.50)

var active := false
var arena_min_x := 0.0
var arena_max_x := 0.0
var ground_y := 0.0
var home_pos := Vector3.ZERO

var state := "dormant"
var state_t := 0.0
var attack_cd := 2.2
var phase := 1

var _t := randf() * TAU
var _face := -1.0
var _contact_cd := 0.0
var _aim_time := TELEGRAPH_CHARGE
var _recover_time := 0.9
var _charge_dir := 1.0
var _charge_hit := false
var _charge_chain := 0
var _volleys_fired := 0
var _volley_t := 0.0
var _wave2_t := 0.0
var _summon_flags := [false, false]
var _summon_fired := false
var _telegraph: MeshInstance3D = null
var _spr_base := Color.WHITE

# 外观引用（模型 / 立绘 / 程序化三种模式下会有不同的一批为 null）
var model: Node3D = null
var body_mat: StandardMaterial3D
var plate_mat: StandardMaterial3D
var core_mat: StandardMaterial3D
var visor_mat: StandardMaterial3D
var core: MeshInstance3D
var boss_light: OmniLight3D


func _setup() -> void:
	max_hp = 520.0
	hp = max_hp
	touch_damage = 14.0
	uses_gravity = true
	knock_resist = 0.97
	collision_mask = 1
	# 余烬橙轮廓：熔池背景是暗红，冷色边会让重甲看起来是"铁块"而不是剪影
	rim_color = Color(1.0, 0.55, 0.22, 0.95)
	add_hitbox(1.25, 3.0, 1.5)
	home_pos = global_position
	if arena_max_x <= arena_min_x:
		arena_min_x = global_position.x - 12.0
		arena_max_x = global_position.x + 12.0
	# 关卡应显式传入地面高度；没传时退化为出生高度（走地 Boss 就站在出生点）
	if is_zero_approx(ground_y) and not is_zero_approx(global_position.y):
		ground_y = global_position.y


# ================================================================ 外观

func _build_gfx() -> void:
	## 优先级：专属模型 > 立绘 > 程序化重甲（本项目第二章用最后一级兜底）
	model = Game.load_model("res://art/models/warden.glb", 3.9, 180.0)
	if model:
		model.position.y = 0.0
		gfx.add_child(model)
		_add_armor_overlay()
		_add_aura()
		return
	var tex := Game.tex("res://art/sprites/warden_idle.png")
	if tex:
		spr = make_sprite(tex, SPR_H, SPR_H * 0.5)
		_add_aura()
		return
	_build_body()
	_add_aura()


func _build_body() -> void:
	## 程序化重甲狱卒：铁灰重甲 + 狱火核心 + 棘冠 + 巨棘锤 + 锁链
	body_mat = Game.std_mat(C_IRON, Color(0.28, 0.05, 0.02), 0.5, 0.8, 0.5)
	plate_mat = Game.std_mat(Color(0.46, 0.26, 0.17),
		Color(0.5, 0.1, 0.04), 0.4, 0.55, 0.65)
	core_mat = Game.std_mat(C_CORE, C_EMBER, 2.6, 0.25)
	visor_mat = Game.std_mat(Color(1.0, 0.3, 0.1), C_EMBER, 2.2, 0.3)
	var chain_mat := Game.std_mat(Color(0.55, 0.42, 0.2),
		Color(0.3, 0.18, 0.05), 0.5, 0.45, 0.8)

	# 脚 / 小腿 / 腿甲
	var foot := BoxMesh.new()
	foot.size = Vector3(0.62, 0.3, 0.95)
	var shin := CylinderMesh.new()
	shin.top_radius = 0.2
	shin.bottom_radius = 0.26
	shin.height = 0.8
	shin.radial_segments = 8
	var thigh := BoxMesh.new()
	thigh.size = Vector3(0.52, 0.7, 0.72)
	for sx: float in [-0.4, 0.4]:
		Game.add_mesh(gfx, foot, body_mat, Vector3(sx, 0.15, 0))
		Game.add_mesh(gfx, shin, body_mat, Vector3(sx, 0.7, 0))
		Game.add_mesh(gfx, thigh, plate_mat, Vector3(sx, 1.35, 0))
	# 腰 / 躯干 / 胸甲
	var waist := BoxMesh.new()
	waist.size = Vector3(1.25, 0.4, 0.95)
	Game.add_mesh(gfx, waist, body_mat, Vector3(0, 1.75, 0))
	var torso := BoxMesh.new()
	torso.size = Vector3(1.35, 1.3, 1.05)
	Game.add_mesh(gfx, torso, body_mat, Vector3(0, 2.6, 0))
	var chest := BoxMesh.new()
	chest.size = Vector3(0.3, 1.0, 0.9)
	Game.add_mesh(gfx, chest, plate_mat, Vector3(0.68, 2.65, 0))
	# 肩甲
	var pauldron := SphereMesh.new()
	pauldron.radius = 0.5
	pauldron.height = 1.0
	for sz: float in [-0.55, 0.55]:
		Game.add_mesh(gfx, pauldron, plate_mat, Vector3(0.05, 3.3, sz),
			Vector3.ZERO, Vector3(1.15, 0.85, 1.0))
	# 头 / 面甲 / 目缝
	var head := BoxMesh.new()
	head.size = Vector3(0.68, 0.62, 0.7)
	Game.add_mesh(gfx, head, body_mat, Vector3(0.05, 3.75, 0))
	var face := BoxMesh.new()
	face.size = Vector3(0.28, 0.5, 0.72)
	Game.add_mesh(gfx, face, plate_mat, Vector3(0.4, 3.72, 0))
	var visor := BoxMesh.new()
	visor.size = Vector3(0.08, 0.1, 0.5)
	Game.add_mesh(gfx, visor, visor_mat, Vector3(0.55, 3.78, 0))
	# 两侧狱火眼（2.5D 侧视里无论朝哪边都能看到一点红光）
	var eye := SphereMesh.new()
	eye.radius = 0.09
	eye.height = 0.18
	for sz: float in [-0.34, 0.34]:
		Game.add_mesh(gfx, eye, visor_mat, Vector3(0.42, 3.78, sz))
	# 棘冠（朝上、朝后）
	var horn := CylinderMesh.new()
	horn.top_radius = 0.0
	horn.bottom_radius = 0.12
	horn.height = 0.95
	horn.radial_segments = 7
	for i in 3:
		Game.add_mesh(gfx, horn, plate_mat,
			Vector3(-0.1 - i * 0.22, 4.2 - i * 0.12, 0),
			Vector3(0, 0, 18 + i * 16))
	# 背部棘刺
	for i in 3:
		Game.add_mesh(gfx, horn, body_mat,
			Vector3(-0.62, 2.9 - i * 0.35, 0),
			Vector3(0, 0, 75 - i * 20), Vector3(0.7, 0.7, 0.7))
	# 巨棘锤（立在 +z 侧，镜头可见）
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.075
	shaft.bottom_radius = 0.095
	shaft.height = 2.6
	shaft.radial_segments = 8
	Game.add_mesh(gfx, shaft, body_mat, Vector3(0.55, 2.2, 0.72),
		Vector3(0, 0, -8))
	var hammer := BoxMesh.new()
	hammer.size = Vector3(0.62, 0.7, 0.62)
	Game.add_mesh(gfx, hammer, plate_mat, Vector3(0.72, 3.58, 0.72))
	for i in 4:
		Game.add_mesh(gfx, horn, plate_mat, Vector3(0.72, 3.58, 0.72),
			Vector3(0, 0, i * 90), Vector3(0.6, 0.45, 0.6))
	# 肩部锁链
	var link := TorusMesh.new()
	link.inner_radius = 0.1
	link.outer_radius = 0.17
	for i in 4:
		Game.add_mesh(gfx, link, chain_mat,
			Vector3(-0.5, 3.0 - i * 0.3, 0.62), Vector3(0, 0, 90 * (i % 2)))
	# 胸口狱火核心：预警时靠它发光
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.26
	core_mesh.height = 0.52
	core = Game.add_mesh(gfx, core_mesh, core_mat, Vector3(0.86, 2.6, 0))


func _add_armor_overlay() -> void:
	## 模型模式下的重甲外挂件：甲片 / 核心 / 锁链（模型缺失时不会走到这里）
	body_mat = Game.std_mat(C_IRON, Color(0.28, 0.05, 0.02), 0.5, 0.8, 0.5)
	plate_mat = Game.std_mat(Color(0.46, 0.26, 0.17),
		Color(0.5, 0.1, 0.04), 0.4, 0.55, 0.65)
	core_mat = Game.std_mat(C_CORE, C_EMBER, 2.6, 0.25)
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.3
	core_mesh.height = 0.6
	core = Game.add_mesh(gfx, core_mesh, core_mat, Vector3(0.9, 1.9, 0.2))
	var band := TorusMesh.new()
	band.inner_radius = 1.05
	band.outer_radius = 1.25
	Game.add_mesh(gfx, band, plate_mat, Vector3(0, 1.75, 0),
		Vector3(0, 0, 90), Vector3(1, 1, 0.55))


func _add_aura() -> void:
	# 甲缝里冒出的狱火余烬
	var p := GPUParticles3D.new()
	p.amount = 22
	p.lifetime = 1.8
	p.position = Vector3(0, 1.4, 0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(1.0, 1.2, 0.6)
	pm.direction = Vector3.UP
	pm.spread = 25.0
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 1.1
	pm.gravity = Vector3(0, 0.6, 0)
	pm.color = Color(1.0, 0.42, 0.12, 0.6)
	p.process_material = pm
	var dm := SphereMesh.new()
	dm.radius = 0.05
	dm.height = 0.1
	dm.radial_segments = 5
	dm.rings = 3
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(1.0, 0.6, 0.2, 0.7)
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dmat.vertex_color_use_as_albedo = true
	dm.material = dmat
	p.draw_pass_1 = dm
	gfx.add_child(p)

	boss_light = OmniLight3D.new()
	boss_light.light_color = Color(1.0, 0.5, 0.2)
	boss_light.light_energy = 2.2
	boss_light.omni_range = 13.0
	boss_light.light_volumetric_fog_energy = 0.3
	boss_light.shadow_enabled = false
	boss_light.position = Vector3(0, 2.4, 0.8)
	gfx.add_child(boss_light)


# ================================================================ 激活 / 行为

func activate() -> void:
	if active or dead:
		return
	active = true
	state = "idle"
	state_t = 0.0
	attack_cd = 2.0
	Game.play_sfx("roar", 0.0)
	Game.shake(0.8)
	boss_hp_changed.emit(hp, max_hp)


func _behave(delta: float) -> void:
	_t += delta
	state_t += delta
	_contact_cd = maxf(_contact_cd - delta, 0.0)
	_update_visual(delta)
	_update_delayed_wave(delta)

	if not active:
		# 沉睡：站定、锁链轻晃
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		gfx.position.y = sin(_t * 0.9) * 0.03
		return

	# 朝向玩家（立绘原图朝右）；冲锋方向在起手时已锁死，蓄力中不能反悔，
	# 否则地面轨道预警会骗人
	if state == "charge_aim" or state == "charge":
		_face = _charge_dir
	elif player_alive():
		var dx := player.global_position.x - global_position.x
		if absf(dx) > 0.4:
			_face = signf(dx)
	if _face == 0.0:
		_face = 1.0
	if spr:
		spr.flip_h = _face < 0.0
	var yaw := 0.0 if _face > 0.0 else PI
	gfx.rotation.y = lerp_angle(gfx.rotation.y, yaw, 8.0 * delta)

	# 阶段切换
	if phase == 1 and hp <= max_hp * 0.5:
		_enter_phase2()
		return

	# 召唤只在待机态触发，避免打断正在预警的招式
	if state == "idle":
		if not _summon_flags[0] and hp <= max_hp * 0.68:
			_summon_flags[0] = true
			_begin_summon()
			return
		if not _summon_flags[1] and hp <= max_hp * 0.3:
			_summon_flags[1] = true
			_begin_summon()
			return

	# 重甲挤压（贴身时的轻伤害，给"别站在 Boss 里"的反馈）
	if player_alive() and _contact_cd <= 0.0 and dist_to_player() < 1.9 \
			and state != "charge":
		_contact_cd = 1.4
		player.take_damage(CONTACT_DMG, global_position.x)

	match state:
		"idle":
			_state_idle(delta)
		"charge_aim":
			_state_charge_aim(delta)
		"charge":
			_state_charge(delta)
		"recover":
			_state_recover(delta)
		"slam_raise":
			_state_slam_raise(delta)
		"slam_impact":
			velocity.x = 0.0
			if state_t >= 0.22:
				state = "recover"
				state_t = 0.0
				_recover_time = 0.8
		"barrage_aim":
			_state_barrage_aim(delta)
		"barrage":
			_state_barrage(delta)
		"summon":
			_state_summon(delta)
		_:
			state = "idle"
			state_t = 0.0


func _state_idle(delta: float) -> void:
	var spd := 2.4 if phase == 1 else 3.2
	if player_alive() and dist_to_player() > 2.7:
		var dir := signf(player.global_position.x - global_position.x)
		velocity.x = move_toward(velocity.x, dir * spd, 14.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 16.0 * delta)
	_clamp_arena()
	attack_cd -= delta
	if attack_cd <= 0.0 and player_alive():
		_pick_attack()


func _pick_attack() -> void:
	state_t = 0.0
	_charge_chain = 0
	var d := dist_to_player()
	var roll := randf()
	if d > 11.0:
		# 离得远：先冲锋贴近或弹幕压血线
		state = "charge_aim" if roll < 0.55 else "barrage_aim"
	elif roll < 0.40:
		state = "charge_aim"
	elif roll < 0.74:
		state = "slam_raise"
	else:
		state = "barrage_aim"
	if state == "charge_aim":
		_aim_time = TELEGRAPH_CHARGE
		_charge_dir = _face
		_charge_hit = false
		_show_charge_line(_charge_dir)
	elif state == "slam_raise":
		_show_telegraph(Vector3(global_position.x, ground_y + 0.12, 0), 3.7)
	elif state == "barrage_aim":
		_show_telegraph(Vector3(global_position.x, ground_y + 0.12, 0), 1.8)


func _state_charge_aim(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 26.0 * delta)
	_set_glow(state_t / _aim_time)
	if state_t >= _aim_time:
		_begin_charge()


func _begin_charge() -> void:
	_clear_telegraph()
	state = "charge"
	state_t = 0.0
	_charge_hit = false
	if _charge_dir == 0.0:
		_charge_dir = _face
	Game.play_sfx("roar", -4.0, 1.3)
	Game.shake(0.5)
	Game.burst(get_parent(), global_position + Vector3(0, 0.4, 0),
		Color(0.9, 0.4, 0.12), 20, 5.0, 0.1, 0.5)


func _state_charge(delta: float) -> void:
	velocity.x = _charge_dir * CHARGE_SPEED
	if player_alive() and not _charge_hit:
		var p := player.global_position
		if absf(p.x - global_position.x) < 2.2 and p.y < ground_y + 3.4:
			_charge_hit = true
			player.take_damage(20.0, global_position.x)
			Game.shake(0.6)
			Game.burst(get_parent(), p + Vector3(0, 1.0, 0),
				Color(1.0, 0.45, 0.15), 24, 7.0, 0.1, 0.6)
	# 撞到竞技场边界：进入硬直；二阶段还会反向再冲一段
	var hit_edge := (_charge_dir > 0.0 and
		global_position.x >= arena_max_x - 2.2) or \
		(_charge_dir < 0.0 and global_position.x <= arena_min_x + 2.2)
	if hit_edge or state_t >= 1.5:
		_end_charge()
	# 冲锋扬尘
	if fmod(_t, 0.06) < delta:
		Game.burst(get_parent(),
			global_position + Vector3(-_charge_dir * 1.2, 0.25, 0),
			Color(0.55, 0.3, 0.18, 0.5), 6, 2.5, 0.07, 0.35)


func _end_charge() -> void:
	Game.burst(get_parent(), global_position + Vector3(0, 0.6, 0),
		Color(0.85, 0.42, 0.14), 26, 6.5, 0.1, 0.6)
	Game.shake(0.55)
	if phase == 2 and _charge_chain < 1 and player_alive():
		# 二阶段规则变化：第一段撞墙后立刻反向二连突进
		_charge_chain += 1
		state = "charge_aim"
		state_t = 0.0
		_aim_time = TELEGRAPH_CHARGE_FAST
		_charge_dir = signf(player.global_position.x - global_position.x)
		if _charge_dir == 0.0:
			_charge_dir = _face
		_face = _charge_dir
		_show_charge_line(_charge_dir)
	else:
		_charge_chain = 0
		state = "recover"
		state_t = 0.0
		_recover_time = 0.9
		velocity.x = 0.0


func _state_recover(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
	if state_t >= _recover_time:
		state = "idle"
		state_t = 0.0
		attack_cd = 2.2 if phase == 1 else 1.5
		_set_glow(0.0)


func _state_slam_raise(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 28.0 * delta)
	_set_glow(state_t / TELEGRAPH_SLAM)
	if state_t >= TELEGRAPH_SLAM:
		_clear_telegraph()
		state = "slam_impact"
		state_t = 0.0
		velocity.x = 0.0
		_slam_impact()


func _state_barrage_aim(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 28.0 * delta)
	_set_glow(state_t / TELEGRAPH_BARRAGE)
	if state_t >= TELEGRAPH_BARRAGE:
		_clear_telegraph()
		state = "barrage"
		state_t = 0.0
		_volleys_fired = 0
		_volley_t = 0.0


func _state_barrage(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 28.0 * delta)
	_volley_t -= delta
	if _volley_t <= 0.0:
		_fire_fan()
		_volleys_fired += 1
		_volley_t = 0.3
	var total := 1 if phase == 1 else 3
	if _volleys_fired >= total:
		_set_glow(0.0)
		state = "recover"
		state_t = 0.0
		_recover_time = 0.5


func _state_summon(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 24.0 * delta)
	_set_glow(state_t / TELEGRAPH_SUMMON)
	if not _summon_fired and state_t >= TELEGRAPH_SUMMON:
		_summon_fired = true
		summon_requested.emit(2 if phase == 1 else 3)
		Game.burst(get_parent(), global_position + Vector3(0, 2.0, 0),
			Color(0.8, 0.25, 0.1), 40, 8.0, 0.12, 0.9)
		Game.shake(0.6)
	if state_t >= TELEGRAPH_SUMMON + 0.45:
		_set_glow(0.0)
		state = "recover"
		state_t = 0.0
		_recover_time = 0.55


func _begin_summon() -> void:
	if not active:
		return
	_clear_telegraph()
	state = "summon"
	state_t = 0.0
	_summon_fired = false
	Game.play_sfx("roar", -3.0, 1.1)
	Game.shake(0.4)


# ---------------------------------------------------------------- 招式实现

func _slam_impact() -> void:
	Game.play_sfx("heavy", 2.0, 0.55)
	Game.shake(1.0)
	var gp := Vector3(global_position.x, ground_y + 0.35, 0)
	Game.burst(get_parent(), gp, Color(0.9, 0.4, 0.12), 44, 9.5, 0.13, 0.9)
	Game.burst(get_parent(), gp, Color(0.4, 0.24, 0.2), 22, 5.0, 0.1, 0.6)
	# 砸地范围伤害
	if player_alive():
		var p := player.global_position
		if absf(p.x - global_position.x) < 3.7 and p.y < ground_y + 2.8:
			player.take_damage(26.0, global_position.x)
	_spawn_wave()
	# 二阶段规则变化：追加第二波冲击波（错开 0.45s）
	if phase == 2:
		_wave2_t = 0.45


func _spawn_wave() -> void:
	for dir: float in [-1.0, 1.0]:
		var proj := Projectile.new()
		proj.dmg = 13.0
		proj.tint = Color(1.0, 0.38, 0.12)
		proj.vel = Vector3(dir * 9.0, 0.0, 0.0)
		proj.life = 2.4
		proj.position = Vector3(global_position.x + dir * 1.8,
			ground_y + 0.6, 0)
		get_parent().add_child(proj)


func _update_delayed_wave(delta: float) -> void:
	if _wave2_t <= 0.0:
		return
	_wave2_t -= delta
	if _wave2_t <= 0.0:
		Game.burst(get_parent(), global_position + Vector3(0, 0.3, 0),
			Color(0.9, 0.4, 0.12), 24, 6.0, 0.1, 0.6)
		Game.shake(0.4)
		_spawn_wave()


func _fire_fan() -> void:
	if not player_alive():
		return
	Game.play_sfx("shoot", -4.0, 0.65)
	var origin := global_position + Vector3(0, 2.4, 0)
	var to_player := (player.global_position + Vector3(0, 0.9, 0) -
		origin).normalized()
	var base_angle := atan2(to_player.y, to_player.x)
	var n := 5 if phase == 1 else 7
	var spread := 20.0 if phase == 1 else 30.0
	var spd := 7.0 if phase == 1 else 8.0
	for i in n:
		var a := base_angle + deg_to_rad(-spread + 2.0 * spread *
			float(i) / maxf(n - 1, 1))
		var proj := Projectile.new()
		proj.dmg = 11.0
		proj.tint = Color(1.0, 0.5, 0.15)
		proj.vel = Vector3(cos(a), sin(a), 0.0) * spd
		proj.position = origin + proj.vel.normalized() * 1.7
		get_parent().add_child(proj)


# ---------------------------------------------------------------- 表现 / 预警

func _update_visual(delta: float) -> void:
	# 走动的沉重起伏
	var walk := clampf(absf(velocity.x) / 4.0, 0.0, 1.0)
	gfx.position.y = absf(sin(_t * 7.0)) * 0.07 * walk
	# 身体前倾 / 后仰（招式读感）
	var lean := 0.0
	match state:
		"charge":
			lean = -_face * 0.14
		"charge_aim", "slam_raise":
			lean = 0.05
		"recover":
			lean = -0.06
		_:
			lean = 0.0
	gfx.rotation.z = lerpf(gfx.rotation.z, lean, 8.0 * delta)
	# 缩胀（砸地抬身 / 落锤 / 召唤颤动）
	var sc := 1.0
	if state == "slam_raise":
		sc = 1.0 + 0.08 * clampf(state_t / TELEGRAPH_SLAM, 0.0, 1.0)
	elif state == "slam_impact":
		sc = 0.93
	elif state == "summon":
		sc = 1.0 + sin(state_t * 16.0) * 0.03
	gfx.scale = gfx.scale.lerp(Vector3(sc, sc, sc), 10.0 * delta)


func _set_glow(c: float) -> void:
	## 蓄力发光：立绘增亮 / 网格的核心与甲缝增亮 / 三种模式都调灯光
	c = clampf(c, 0.0, 1.2)
	if spr:
		spr.modulate = _spr_base * Color(1.0 + c, 1.0 + c * 0.45, 1.0 + c * 0.3)
		spr.set_meta("base_mod", spr.modulate)
	if core_mat:
		core_mat.emission_energy_multiplier = (2.6 if phase == 1 else 3.6) \
			+ c * 6.0
	if core:
		core.scale = Vector3.ONE * (1.0 + c * 0.35)
	if plate_mat:
		plate_mat.emission_energy_multiplier = (0.4 if phase == 1 else 1.0) \
			+ c * 2.6
	if body_mat:
		body_mat.emission_energy_multiplier = (0.5 if phase == 1 else 1.2) \
			+ c * 2.2
	if boss_light:
		boss_light.light_energy = (2.2 if phase == 1 else 3.2) + c * 4.0


func _show_telegraph(pos: Vector3, radius: float) -> void:
	## 地面预警红环：砸地 / 弹幕起手
	_clear_telegraph()
	var torus := TorusMesh.new()
	torus.inner_radius = radius * 0.86
	torus.outer_radius = radius
	torus.ring_segments = 28
	torus.rings = 6
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.22, 0.12, 0.5)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.24, 0.1)
	mat.emission_energy_multiplier = 2.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_telegraph = MeshInstance3D.new()
	_telegraph.mesh = torus
	_telegraph.material_override = mat
	_telegraph.position = pos
	_telegraph.scale = Vector3(1.0, 0.14, 1.0)
	get_parent().add_child(_telegraph)
	var tw := _telegraph.create_tween()
	tw.set_loops()
	tw.tween_property(mat, "emission_energy_multiplier", 4.5, 0.16)
	tw.tween_property(mat, "emission_energy_multiplier", 1.4, 0.16)


func _show_charge_line(dir: float) -> void:
	## 冲锋轨道预警：地面一条红带，标出这次冲锋会扫过的路径
	_clear_telegraph()
	var edge := arena_max_x - 1.8 if dir > 0.0 else arena_min_x + 1.8
	var length := absf(edge - global_position.x)
	if length < 2.0:
		length = 2.0
	var box := BoxMesh.new()
	box.size = Vector3(length, 0.04, 1.5)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.25, 0.1, 0.32)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.3, 0.1)
	mat.emission_energy_multiplier = 1.6
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_telegraph = MeshInstance3D.new()
	_telegraph.mesh = box
	_telegraph.material_override = mat
	_telegraph.position = Vector3(
		global_position.x + dir * length * 0.5, ground_y + 0.09, 0)
	get_parent().add_child(_telegraph)
	var tw := _telegraph.create_tween()
	tw.set_loops()
	tw.tween_property(mat, "emission_energy_multiplier", 4.0, 0.16)
	tw.tween_property(mat, "emission_energy_multiplier", 1.2, 0.16)


func _clear_telegraph() -> void:
	if _telegraph and is_instance_valid(_telegraph):
		_telegraph.queue_free()
	_telegraph = null


func _clamp_arena() -> void:
	if global_position.x < arena_min_x + 1.5:
		global_position.x = arena_min_x + 1.5
	elif global_position.x > arena_max_x - 1.5:
		global_position.x = arena_max_x - 1.5


# ================================================================ 阶段 / 重置 / 生死

func _enter_phase2() -> void:
	phase = 2
	set_rim_color(Color(1.0, 0.3, 0.15, 1.0))   # 二阶段轮廓转炽红
	state = "recover"
	state_t = 0.0
	_recover_time = 1.0
	_charge_chain = 0
	_wave2_t = 0.0
	_clear_telegraph()
	Game.play_sfx("roar", 2.0, 0.8)
	Game.shake(1.1)
	Game.hitstop(0.25, 0.1)
	# 外观：体表泛红 + 狱火溢出（模型 / 立绘 / 网格各自判空）
	if spr:
		_spr_base = Color(1.45, 0.78, 0.62)
		_set_glow(0.0)
	if model:
		_apply_model_tint(MODEL_TINT_P2, Color(1.0, 0.22, 0.08), 0.9)
	if body_mat:
		body_mat.emission = Color(0.9, 0.18, 0.08)
	if plate_mat:
		plate_mat.albedo_color = Color(0.58, 0.18, 0.10)
		plate_mat.emission = Color(1.0, 0.25, 0.08)
	if core_mat:
		core_mat.emission = Color(1.0, 0.5, 0.1)
	if visor_mat:
		visor_mat.albedo_color = Color(1.0, 0.2, 0.06)
	if boss_light:
		boss_light.light_color = Color(1.0, 0.34, 0.14)
		boss_light.light_energy = 3.4
	Game.burst(get_parent(), global_position + Vector3(0, 2.0, 0),
		Color(1.0, 0.3, 0.12), 60, 11.0, 0.15, 1.1)
	Game.spawn_dmg_text(get_parent(), global_position + Vector3(0, 5.0, 0),
		"狱火解封", Color(1.0, 0.48, 0.2), true)


func _apply_model_tint(tint: Color, emission: Color, e_energy: float) -> void:
	## 模型模式下给网格染色；烘焙贴图的模型要复制一份材质，别把贴图丢掉
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi.material_override as StandardMaterial3D
		if m == null:
			if mi.mesh and mi.mesh.get_surface_count() > 0:
				var src := mi.mesh.surface_get_material(0) as StandardMaterial3D
				if src:
					m = src.duplicate() as StandardMaterial3D
					mi.material_override = m
					mi.set_meta("base_mat", m)
		if m == null:
			continue
		m.albedo_color = tint
		m.emission_enabled = e_energy > 0.0
		m.emission = emission
		m.emission_energy_multiplier = e_energy


func reset_fight() -> void:
	## 玩家阵亡后完整重置 Boss 战
	if dead:
		return
	active = false
	hp = max_hp
	phase = 1
	state = "dormant"
	state_t = 0.0
	attack_cd = 2.2
	_charge_chain = 0
	_charge_hit = false
	_volleys_fired = 0
	_volley_t = 0.0
	_wave2_t = 0.0
	_summon_flags = [false, false]
	_summon_fired = false
	_contact_cd = 0.0
	_burn_left = 0.0
	_clear_telegraph()
	global_position = home_pos
	velocity = Vector3.ZERO
	gfx.position = Vector3.ZERO
	gfx.rotation.z = 0.0
	gfx.scale = Vector3.ONE
	# 还原一阶段外观：三种模式下的引用不同，必须逐个判空
	if spr:
		_spr_base = Color.WHITE
		_set_glow(0.0)
	if model:
		_apply_model_tint(MODEL_TINT_P1, Color(0.5, 0.08, 0.03), 0.25)
	if body_mat:
		body_mat.emission = Color(0.28, 0.05, 0.02)
	if plate_mat:
		plate_mat.albedo_color = Color(0.46, 0.26, 0.17)
		plate_mat.emission = Color(0.5, 0.1, 0.04)
	if core_mat:
		core_mat.emission = C_EMBER
	if visor_mat:
		visor_mat.albedo_color = Color(1.0, 0.3, 0.1)
	if core:
		core.scale = Vector3.ONE
	_set_glow(0.0)
	boss_hp_changed.emit(hp, max_hp)


func take_damage(dmg: float, dir: float, heavy := false) -> void:
	if not active or dead:
		return
	super.take_damage(dmg, dir, heavy)
	if not dead:
		boss_hp_changed.emit(hp, max_hp)


func die() -> void:
	if dead:
		return
	dead = true
	hp = 0.0
	_clear_telegraph()
	boss_hp_changed.emit(0.0, max_hp)
	Game.play_sfx("boss_die", 2.0)
	Game.shake(1.5)
	Game.hitstop(0.5, 0.12)
	var center := global_position + Vector3(0, 2.0, 0)
	for i in 4:
		Game.burst(get_parent(), center + Vector3(randf_range(-1.6, 1.6),
			randf_range(-1.2, 1.6), 0), Color(1.0, 0.4, 0.12), 34, 11.0,
			0.15, 1.2)
	Game.burst(get_parent(), center, Color(1.0, 0.82, 0.35), 50, 12.0,
		0.12, 1.4)
	boss_defeated.emit()
	# 重甲崩解下沉
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(gfx, "scale", Vector3(0.08, 0.08, 0.08), 1.6) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "global_position:y", ground_y - 2.5, 1.6) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(queue_free)
