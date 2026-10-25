class_name BossMaw
extends EnemyBase
## 归墟之喉 · 渊狱兽：悬浮巨眼 Boss
## 招式：俯冲砸地（冲击波）/ 渊涡弹幕 / 横扫冲锋（二阶段）/ 召唤爬行者

signal boss_hp_changed(hp: float, max_hp: float)
signal summon_requested(count: int)
signal boss_defeated

var active := false
var arena_min_x := 0.0
var arena_max_x := 0.0
var ground_y := 0.0
var home_pos := Vector3.ZERO

var state := "dormant"
var state_t := 0.0
var attack_cd := 2.0
var phase := 1
var _t := randf() * TAU
var _slam_x := 0.0
var _sweep_dir := 1.0
var _sweep_hit := false
var _contact_cd := 0.0
var _summon_flags := [false, false]
var _telegraph: MeshInstance3D = null

var eye_mat: StandardMaterial3D
var body_mat: StandardMaterial3D
var eye: MeshInstance3D
var pupil: MeshInstance3D
var _tentacles: Array[MeshInstance3D] = []
var boss_light: OmniLight3D


func _setup() -> void:
	max_hp = 480.0
	hp = max_hp
	uses_gravity = false
	collision_mask = 0
	knock_resist = 0.96
	rim_color = Color(0.8, 0.42, 1.0, 0.9)
	add_hitbox(1.7, 3.4, 0.0)
	home_pos = global_position


const SPR_H := 4.6


var model: Node3D = null
var boss_motion: RefCounted


func _build_gfx() -> void:
	model = Game.load_model("res://art/models/bosses_arp/01_maw.glb", 4.4, -90.0,
		0.0, 0.0, true, false)
	if model:
		model.position.y = -2.2
		gfx.add_child(model)
		boss_motion = preload("res://scripts/boss_motion.gd").new(model, "maw")
		_add_aura()
		return
	model = Game.load_model("res://art/models/boss.glb", 4.4, 180.0,
		-90.0, 0.0, true, false)
	if model:
		model.position.y = -2.2
		gfx.add_child(model)
		_add_aura()
		return
	var tex := Game.tex("res://art/sprites/boss_idle.png")
	if tex:
		spr = make_sprite(tex, SPR_H, 0.1)
		_add_aura()
		return
	body_mat = Game.std_mat(Color(0.1, 0.05, 0.16), Color(0.25, 0.08, 0.4),
		0.5, 0.55)
	var body := SphereMesh.new()
	body.radius = 1.6
	body.height = 3.2
	Game.add_mesh(gfx, body, body_mat, Vector3.ZERO,
		Vector3.ZERO, Vector3(1.0, 1.1, 1.0))

	# 巨眼（朝 -x，玩家来向）
	eye_mat = Game.std_mat(Color(0.85, 0.3, 1.0), Color(0.8, 0.25, 1.0), 2.2, 0.25)
	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.62
	eye_mesh.height = 1.24
	eye = Game.add_mesh(gfx, eye_mesh, eye_mat, Vector3(-1.15, 0.25, 0))
	var pupil_mesh := SphereMesh.new()
	pupil_mesh.radius = 0.3
	pupil_mesh.height = 0.6
	pupil = Game.add_mesh(gfx, pupil_mesh,
		Game.std_mat(Color(0.02, 0.0, 0.05), Color.BLACK, 1.0, 0.2),
		Vector3(-1.55, 0.25, 0))

	# 環形獠牙
	var tooth := CylinderMesh.new()
	tooth.top_radius = 0.0
	tooth.bottom_radius = 0.14
	tooth.height = 0.65
	var tooth_mat := Game.std_mat(Color(0.75, 0.72, 0.65),
		Color(0.3, 0.28, 0.2), 0.3, 0.45)
	for i in 10:
		var a := TAU * i / 10.0
		var r := 1.05
		Game.add_mesh(gfx, tooth, tooth_mat,
			Vector3(-1.05, 0.25 + cos(a) * r, sin(a) * r),
			Vector3(rad_to_deg(a) + 90.0, 0, 90))

	# 背棘冠
	var crown := CylinderMesh.new()
	crown.top_radius = 0.0
	crown.bottom_radius = 0.2
	crown.height = 1.1
	var crown_mat := Game.std_mat(Color(0.2, 0.1, 0.3), Color(0.4, 0.1, 0.6),
		0.8, 0.5)
	for i in 5:
		Game.add_mesh(gfx, crown, crown_mat,
			Vector3(0.3 + i * 0.25, 1.4 - absf(i - 2.0) * 0.15, 0),
			Vector3(0, 0, -20 - i * 10))

	# 垂下的触须
	var tent := CylinderMesh.new()
	tent.top_radius = 0.16
	tent.bottom_radius = 0.03
	tent.height = 2.4
	var tent_mat := Game.std_mat(Color(0.16, 0.07, 0.24),
		Color(0.3, 0.08, 0.45), 0.6, 0.5)
	for i in 6:
		var a := TAU * i / 6.0
		var t := Game.add_mesh(gfx, tent, tent_mat,
			Vector3(cos(a) * 0.85, -1.9, sin(a) * 0.85))
		_tentacles.append(t)

	_add_aura()


func _add_aura() -> void:
	# 暗涌粒子
	var p := GPUParticles3D.new()
	p.amount = 24
	p.lifetime = 1.6
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 40.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 1.5
	pm.gravity = Vector3(0, 0.8, 0)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 1.6
	pm.color = Color(0.5, 0.2, 0.8, 0.35)
	p.process_material = pm
	var dm := SphereMesh.new()
	dm.radius = 0.06
	dm.height = 0.12
	dm.radial_segments = 5
	dm.rings = 3
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.6, 0.3, 0.9, 0.5)
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dmat.vertex_color_use_as_albedo = true
	dm.material = dmat
	p.draw_pass_1 = dm
	gfx.add_child(p)

	boss_light = OmniLight3D.new()
	boss_light.light_color = Color(0.6, 0.25, 0.95)
	boss_light.light_energy = 2.5
	boss_light.omni_range = 12.0
	boss_light.shadow_enabled = false
	gfx.add_child(boss_light)


func activate() -> void:
	if active or dead:
		return
	active = true
	state = "hover"
	state_t = 0.0
	attack_cd = 2.2
	# 入场演出：从压扁的小体型"膨胀"出场，避免 Boss 直接凭空出现像闪了一下
	_intro_t = INTRO_TIME
	gfx.scale = Vector3(0.55, 0.55, 0.55)
	Game.play_sfx("roar", 0.0)
	Game.shake(0.8)
	Game.burst(get_parent(), global_position, Color(0.6, 0.25, 0.95),
		36, 7.0, 0.12, 0.8)
	if boss_light:
		boss_light.light_energy = 7.0
	boss_hp_changed.emit(hp, max_hp)


# ---------------------------------------------------------------- 行为

func _behave(delta: float) -> void:
	_t += delta
	_contact_cd = maxf(_contact_cd - delta, 0.0)
	state_t += delta
	var intro_before := _intro_t
	_intro_t = maxf(_intro_t - delta, 0.0)
	if intro_before > 0.0 and _intro_t <= 0.0 and boss_light:
		boss_light.light_energy = 2.5 if phase == 1 else 3.5

	# 触须摆动 / 精灵与模型轻摆
	if spr or model:
		gfx.rotation.z = sin(_t * 1.2) * 0.04
	else:
		for i in _tentacles.size():
			_tentacles[i].rotation.x = sin(_t * 1.8 + i * 1.1) * 0.3
			_tentacles[i].rotation.z = cos(_t * 1.5 + i * 0.7) * 0.25

	if not active:
		# 沉睡：缓慢呼吸
		gfx.scale = Vector3.ONE * (1.0 + sin(_t * 0.8) * 0.02)
		velocity = (home_pos + Vector3(0, sin(_t * 0.9) * 0.3, 0) -
			global_position) * 1.5
		return

	# 面向玩家（立绘原图朝左）
	if player_alive():
		var dx := player.global_position.x - global_position.x
		if spr:
			spr.flip_h = dx > 0.0
		else:
			var yaw := 0.0 if dx < 0.0 else PI
			gfx.rotation.y = lerp_angle(gfx.rotation.y, yaw, 4.0 * delta)

	# 阶段切换
	if phase == 1 and hp <= max_hp * 0.5:
		_enter_phase2()
	# 召唤检查：只在悬停态允许，否则会把砸地/弹幕/横扫整段打断（红圈消失、玩家白闪）
	if state == "hover":
		if not _summon_flags[0] and hp <= max_hp * 0.7:
			_summon_flags[0] = true
			_do_summon()
			return
		if not _summon_flags[1] and hp <= max_hp * 0.35:
			_summon_flags[1] = true
			_do_summon()
			return

	# 近身接触伤害
	if player_alive() and _contact_cd <= 0.0 and dist_to_player() < 2.3 \
			and state != "slam_fall" and state != "sweep":
		_contact_cd = 1.0
		player.take_damage(14.0, global_position.x)

	match state:
		"hover":
			# 垂直浮动从 ±0.5 收窄到 ±0.25：配合悬停高度 6.2→5.0，保证站地近战能打到
			var hover := home_pos + Vector3(sin(_t * 0.5) * 1.5,
				sin(_t * 1.1) * 0.25, 0)
			velocity = (hover - global_position) * 2.0
			if _intro_t > 0.0:
				# 入场膨胀：0.55 → 1.0，缓出
				var t := 1.0 - _intro_t / INTRO_TIME
				var s := lerpf(0.55, 1.0, t * t * (3.0 - 2.0 * t))
				gfx.scale = Vector3.ONE * s
			else:
				gfx.scale = gfx.scale.lerp(Vector3.ONE, 6.0 * delta)
			attack_cd -= delta
			if attack_cd <= 0.0 and player_alive():
				_pick_attack()
		"slam_rise":
			var target := Vector3(clampf(player.global_position.x,
				arena_min_x + 2.0, arena_max_x - 2.0), ground_y + 7.0, 0)
			velocity = (target - global_position) * 3.0
			if state_t >= 0.7:
				_slam_x = clampf(player.global_position.x if player_alive()
					else global_position.x, arena_min_x + 2.0, arena_max_x - 2.0)
				_show_telegraph(Vector3(_slam_x, ground_y + 0.1, 0), 3.2)
				state = "slam_hold"
				state_t = 0.0
		"slam_hold":
			velocity = (Vector3(_slam_x, ground_y + 7.0, 0) -
				global_position) * 3.0
			if state_t >= 0.5:
				state = "slam_fall"
				state_t = 0.0
				Game.play_sfx("swing", -2.0, 0.5)
		"slam_fall":
			velocity = Vector3(0, -34.0, 0)
			gfx.scale = gfx.scale.lerp(Vector3(0.85, 1.25, 0.85), 12.0 * delta)
			if global_position.y <= ground_y + 1.7:
				global_position.y = ground_y + 1.7
				_slam_impact()
		"slam_recover":
			velocity = (home_pos - global_position) * 1.6
			gfx.scale = gfx.scale.lerp(Vector3.ONE, 8.0 * delta)
			if state_t >= 1.0:
				_back_to_hover()
		"barrage":
			velocity = (home_pos + Vector3(0, sin(_t) * 0.4, 0) -
				global_position) * 2.0
			_set_glow(state_t * 0.35)
			var volleys := 2 if phase == 1 else 3
			var interval := 0.95
			for v in volleys:
				if state_t >= 0.6 + v * interval and _barrage_fired <= v:
					_barrage_fired = v + 1
					_fire_fan()
			if state_t >= 0.6 + volleys * interval:
				_set_glow(0.0)
				_back_to_hover()
		"sweep_aim":
			var side := arena_max_x - 2.5 if _sweep_dir < 0.0 else arena_min_x + 2.5
			velocity = (Vector3(side, ground_y + 1.8, 0) - global_position) * 3.5
			_set_glow(state_t * 0.5)
			if state_t >= 0.85:
				state = "sweep"
				state_t = 0.0
				_sweep_hit = false
				Game.play_sfx("roar", -4.0, 1.4)
		"sweep":
			velocity = Vector3(_sweep_dir * 16.5, 0, 0)
			if not _sweep_hit and player_alive() and dist_to_player() < 2.6:
				_sweep_hit = true
				player.take_damage(18.0, global_position.x)
			var past_edge := (_sweep_dir > 0.0 and
				global_position.x >= arena_max_x - 2.0) or \
				(_sweep_dir < 0.0 and global_position.x <= arena_min_x + 2.0)
			if past_edge:
				_set_glow(0.0)
				state = "slam_recover"
				state_t = 0.0
		"summon":
			velocity = (home_pos + Vector3(0, 1.5, 0) - global_position) * 2.0
			gfx.scale = Vector3.ONE * (1.0 + sin(state_t * 20.0) * 0.04)
			if state_t >= 1.1:
				gfx.scale = Vector3.ONE
				_back_to_hover()


var _barrage_fired := 0
var _spr_base := Color.WHITE
const INTRO_TIME := 0.6
var _intro_t := 0.0


func _set_glow(c: float) -> void:
	## 蓄力发光：精灵增亮 / 网格巨眼增亮
	c = clampf(c, 0.0, 1.2)
	if spr:
		spr.modulate = _spr_base * Color(1.0 + c, 1.0 + c * 0.5, 1.0 + c)
		spr.set_meta("base_mod", spr.modulate)
	elif eye_mat:
		eye_mat.emission_energy_multiplier = 2.2 + c * 5.0
	elif boss_light:
		boss_light.light_energy = (2.5 if phase == 1 else 3.5) + c * 2.0


func _pick_attack() -> void:
	state_t = 0.0
	var d := dist_to_player()
	var roll := randf()
	if phase == 2 and roll < 0.32:
		state = "sweep_aim"
		_sweep_dir = -1.0 if player.global_position.x < global_position.x else 1.0
		_sweep_dir = signf(home_pos.x - player.global_position.x)
		if _sweep_dir == 0.0:
			_sweep_dir = 1.0
	elif roll < 0.62 or d > 9.0:
		state = "barrage"
		_barrage_fired = 0
	else:
		state = "slam_rise"


func _back_to_hover() -> void:
	state = "hover"
	state_t = 0.0
	attack_cd = 2.0 if phase == 1 else 1.4


func _show_telegraph(pos: Vector3, radius: float) -> void:
	_clear_telegraph()
	var torus := TorusMesh.new()
	torus.inner_radius = radius * 0.88
	torus.outer_radius = radius
	_telegraph = MeshInstance3D.new()
	_telegraph.mesh = torus
	_telegraph.position = pos
	_telegraph.scale = Vector3(1, 0.15, 1)
	get_parent().add_child(_telegraph)
	var mat := Game.style_warning_ring(_telegraph, radius)
	var tw := _telegraph.create_tween()
	tw.set_loops()
	tw.tween_property(mat, "emission_energy_multiplier", 1.8, 0.18)
	tw.tween_property(mat, "emission_energy_multiplier", 0.9, 0.18)


func _clear_telegraph() -> void:
	if _telegraph and is_instance_valid(_telegraph):
		_telegraph.queue_free()
	_telegraph = null


func _slam_impact() -> void:
	_clear_telegraph()
	state = "slam_recover"
	state_t = 0.0
	Game.play_sfx("heavy", 2.0, 0.6)
	Game.shake(0.9)
	Game.burst(get_parent(), Vector3(_slam_x, ground_y + 0.4, 0),
		Color(0.6, 0.25, 0.9), 40, 9.0, 0.13, 0.8)
	Game.burst(get_parent(), Vector3(_slam_x, ground_y + 0.4, 0),
		Color(0.3, 0.5, 0.7), 20, 5.0, 0.1, 0.6)
	# 砸地范围伤害
	if player_alive():
		var p := player.global_position
		if absf(p.x - _slam_x) < 3.2 and p.y < ground_y + 2.5:
			player.take_damage(22.0, _slam_x)
	# 双向地面冲击波
	for dir in [-1.0, 1.0]:
		var proj := Projectile.new()
		proj.dmg = 12.0
		proj.tint = Color(0.5, 0.3, 0.9)
		proj.vel = Vector3(dir * 7.5, 0, 0)
		proj.life = 2.2
		proj.position = Vector3(_slam_x + dir * 1.5, ground_y + 0.55, 0)
		get_parent().add_child(proj)


func _fire_fan() -> void:
	if not player_alive():
		return
	Game.play_sfx("shoot", -4.0, 0.7)
	var origin := global_position + Vector3(0, 0.2, 0)
	var to_player := (player.global_position + Vector3(0, 1.0, 0) -
		origin).normalized()
	var base_angle := atan2(to_player.y, to_player.x)
	var n := 4
	var spd := 6.2 if phase == 1 else 7.2
	for i in n:
		var a := base_angle + deg_to_rad(-30.0 + 20.0 * i)
		var proj := Projectile.new()
		proj.dmg = 12.0
		proj.vel = Vector3(cos(a), sin(a), 0) * spd
		proj.position = origin + proj.vel.normalized() * 1.6
		get_parent().add_child(proj)


func _do_summon() -> void:
	state = "summon"
	state_t = 0.0
	_clear_telegraph()
	Game.play_sfx("roar", -3.0, 1.2)
	Game.shake(0.5)
	summon_requested.emit(2)


func _enter_phase2() -> void:
	phase = 2
	set_rim_color(Color(1.0, 0.32, 0.38, 0.95))   # 二阶段轮廓转红，远处也能看出状态变化
	Game.play_sfx("roar", 2.0, 0.8)
	Game.shake(1.0)
	Game.hitstop(0.25, 0.1)
	if spr:
		_spr_base = Color(1.45, 0.7, 0.8)
		_set_glow(0.0)
	elif eye_mat:
		eye_mat.albedo_color = Color(1.0, 0.25, 0.3)
		eye_mat.emission = Color(1.0, 0.2, 0.25)
		body_mat.emission = Color(0.5, 0.08, 0.2)
		body_mat.emission_energy_multiplier = 0.8
	elif model:
		# 模型模式：染红
		for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D",
				true, false):
			var m := mi.material_override as StandardMaterial3D
			if m:
				m.albedo_color = Color(1.3, 0.6, 0.7)
	boss_light.light_color = Color(1.0, 0.3, 0.4)
	boss_light.light_energy = 3.5
	Game.burst(get_parent(), global_position, Color(1.0, 0.2, 0.3),
		50, 10.0, 0.14, 1.0)


func reset_fight() -> void:
	## 玩家阵亡后完整重置 Boss 战
	if dead:
		return
	active = false
	if boss_motion:
		boss_motion.reset()
	hp = max_hp
	phase = 1
	state = "dormant"
	state_t = 0.0
	attack_cd = 2.2
	_barrage_fired = 0
	_summon_flags = [false, false]
	_clear_telegraph()
	global_position = home_pos
	velocity = Vector3.ZERO
	_burn_left = 0.0
	_intro_t = 0.0
	gfx.scale = Vector3.ONE
	# 还原一阶段外观（注意：模型模式下 spr / eye_mat 都是 null，必须逐个判空）
	if spr:
		_spr_base = Color.WHITE
		_set_glow(0.0)
	elif eye_mat:
		eye_mat.albedo_color = Color(0.85, 0.3, 1.0)
		eye_mat.emission = Color(0.8, 0.25, 1.0)
		eye_mat.emission_energy_multiplier = 2.2
		if body_mat:
			body_mat.emission = Color(0.25, 0.08, 0.4)
			body_mat.emission_energy_multiplier = 0.5
	elif model:
		for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D",
				true, false):
			var m := mi.material_override as StandardMaterial3D
			if m:
				m.albedo_color = Color.WHITE
	# 灯的复位必须无条件执行，否则二阶段死后重生会一直是红光
	if boss_light:
		boss_light.light_color = Color(0.6, 0.25, 0.95)
		boss_light.light_energy = 2.5
	set_rim_color(Color(0.8, 0.42, 1.0, 0.9))
	boss_hp_changed.emit(hp, max_hp)


# ---------------------------------------------------------------- 生死

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
	if boss_motion:
		boss_motion.die()
	_clear_telegraph()
	boss_hp_changed.emit(0.0, max_hp)
	Game.play_sfx("boss_die", 2.0)
	Game.shake(1.4)
	Game.hitstop(0.5, 0.12)
	var center := global_position
	for i in 4:
		Game.burst(get_parent(), center + Vector3(randf_range(-1.5, 1.5),
			randf_range(-1.0, 1.5), 0), Color(0.7, 0.3, 1.0), 40, 11.0, 0.15, 1.2)
	Game.burst(get_parent(), center, Color(1.0, 0.85, 0.4), 60, 13.0, 0.12, 1.4)
	boss_defeated.emit()
	# 沉没消散
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(gfx, "scale", Vector3(0.05, 0.05, 0.05), 1.6) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "global_position:y", ground_y - 2.0, 1.6) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(queue_free)


func _advance_enemy_motion(delta: float) -> void:
	if boss_motion and not dead:
		boss_motion.step_encounter(delta, self)
