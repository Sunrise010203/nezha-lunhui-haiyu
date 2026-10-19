class_name EnemyCrawler
extends EnemyBase
## 潮汐爬行者：巡逻 → 追击 → 蓄力扑咬

var patrol_min := 0.0
var patrol_max := 0.0
var state := "patrol"
var state_t := 0.0
var move_dir := 1.0
var lunge_cd := 0.0
var _contact_cd := 0.0
var _spikes: Array[MeshInstance3D] = []
var _eye_l: MeshInstance3D
var _eye_r: MeshInstance3D


func _setup() -> void:
	max_hp = 55.0
	hp = max_hp
	touch_damage = 12.0
	rim_color = Color(0.3, 0.95, 0.95, 0.85)   # 青边：和海底背景区分开
	add_hitbox(0.55, 1.0, 0.5)
	if patrol_max <= patrol_min:
		patrol_min = global_position.x - 3.0
		patrol_max = global_position.x + 3.0


var _spr_idle: Texture2D
var _spr_lunge: Texture2D
const SPR_H := 1.25


var model: Node3D = null


func _build_gfx() -> void:
	model = Game.load_model("res://art/models/crawler.glb", 1.1, 180.0)
	if model:
		gfx.add_child(model)
		var ml := OmniLight3D.new()
		ml.light_color = Color(0.7, 0.3, 1.0)
		ml.light_energy = 0.8
		ml.omni_range = 3.0
		ml.position = Vector3(0, 0.6, 0.5)
		ml.shadow_enabled = false
		gfx.add_child(ml)
		Game.tune_small_light(ml, 0.35, 3.2)
		_add_drip()
		return
	_spr_idle = Game.tex("res://art/sprites/crawler_idle.png")
	if _spr_idle:
		_spr_lunge = Game.tex("res://art/sprites/crawler_lunge.png")
		spr = make_sprite(_spr_idle, SPR_H, SPR_H * 0.5)
		return
	var body_mat := Game.std_mat(Color(0.08, 0.2, 0.24),
		Color(0.05, 0.18, 0.2), 0.4, 0.6)
	var spike_mat := Game.std_mat(Color(0.15, 0.3, 0.32),
		Color(0.1, 0.3, 0.3), 0.5, 0.5)
	var eye_mat := Game.std_mat(Color(0.8, 0.3, 1.0), Color(0.7, 0.25, 1.0),
		2.4, 0.3)

	var body := SphereMesh.new()
	body.radius = 0.55
	body.height = 1.1
	Game.add_mesh(gfx, body, body_mat, Vector3(0, 0.5, 0),
		Vector3.ZERO, Vector3(1.25, 0.72, 1.0))
	# 背棘
	var spike := CylinderMesh.new()
	spike.top_radius = 0.0
	spike.bottom_radius = 0.09
	spike.height = 0.45
	for i in 5:
		var s := Game.add_mesh(gfx, spike, spike_mat,
			Vector3(-0.4 + i * 0.2, 0.82, 0),
			Vector3(0, 0, -25 + i * 12))
		_spikes.append(s)
	# 眼睛（朝 +x）
	var eye := SphereMesh.new()
	eye.radius = 0.09
	eye.height = 0.18
	_eye_l = Game.add_mesh(gfx, eye, eye_mat, Vector3(0.55, 0.55, 0.16))
	_eye_r = Game.add_mesh(gfx, eye, eye_mat, Vector3(0.55, 0.55, -0.16))
	_add_drip()


func _add_drip() -> void:
	# 滴落的暗涌粒子
	var drip := GPUParticles3D.new()
	drip.amount = 6
	drip.lifetime = 0.8
	drip.position = Vector3(0, 0.3, 0)
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.DOWN
	pm.spread = 20.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.6
	pm.gravity = Vector3(0, -2, 0)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.5
	pm.color = Color(0.3, 0.15, 0.45, 0.5)
	drip.process_material = pm
	var dm := SphereMesh.new()
	dm.radius = 0.04
	dm.height = 0.08
	dm.radial_segments = 5
	dm.rings = 3
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.4, 0.2, 0.6, 0.6)
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.material = dmat
	drip.draw_pass_1 = dm
	gfx.add_child(drip)


func _behave(delta: float) -> void:
	state_t += delta
	lunge_cd = maxf(lunge_cd - delta, 0.0)
	_contact_cd = maxf(_contact_cd - delta, 0.0)
	var d := dist_to_player()
	var dy := absf(player.global_position.y - global_position.y) \
		if player_alive() else 99.0

	match state:
		"patrol":
			velocity.x = move_toward(velocity.x, move_dir * 2.0, 12.0 * delta)
			if global_position.x > patrol_max:
				move_dir = -1.0
			elif global_position.x < patrol_min:
				move_dir = 1.0
			if d < 7.0 and dy < 2.5:
				state = "chase"
				state_t = 0.0
		"chase":
			if not player_alive() or d > 10.0:
				state = "patrol"
				return
			var dir := signf(player.global_position.x - global_position.x)
			move_dir = dir if dir != 0.0 else move_dir
			# 不冲出平台范围
			var next_x := global_position.x + move_dir * 0.6
			if next_x > patrol_min - 0.5 and next_x < patrol_max + 0.5:
				velocity.x = move_toward(velocity.x, move_dir * 4.2, 16.0 * delta)
			else:
				velocity.x = move_toward(velocity.x, 0.0, 16.0 * delta)
			if d < 2.2 and dy < 1.6 and lunge_cd <= 0.0:
				state = "windup"
				state_t = 0.0
				velocity.x = 0.0
				Game.flash_meshes(gfx, Color(1.0, 0.35, 0.5), 0.14)
				# 第四章：这段起手可以被「定潮 · 架」弹反（前三章 parryable_melee 为 false，无效）
				open_parry_window(0.7)
				var tw := gfx.create_tween()
				tw.tween_property(gfx, "scale", Vector3(0.85, 1.25, 0.85), 0.32)
		"windup":
			velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
			if state_t >= 0.38:
				state = "lunge"
				state_t = 0.0
				velocity.x = move_dir * 11.0
				velocity.y = 3.0
				var tw := gfx.create_tween()
				tw.tween_property(gfx, "scale", Vector3(1.3, 0.7, 1.0), 0.1)
				tw.tween_property(gfx, "scale", Vector3.ONE, 0.25)
				Game.play_sfx("swing", -8.0, 0.6)
		"lunge":
			velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
			if d < 1.7 and _contact_cd <= 0.0 and player_alive():
				_contact_cd = 0.8
				if parry_window_open() and player.has_method("try_parry_melee") \
						and player.try_parry_melee(self):
					state = "chase"
					lunge_cd = 1.0
				else:
					player.take_damage(touch_damage, global_position.x)
			if state_t >= 0.5:
				state = "chase"
				lunge_cd = 1.4
		_:
			state = "patrol"

	# 朝向 + 姿态
	if spr:
		spr.flip_h = move_dir < 0.0
		if state in ["windup", "lunge"] and _spr_lunge:
			set_sprite_tex(_spr_lunge, SPR_H)
		else:
			set_sprite_tex(_spr_idle, SPR_H)
	elif absf(velocity.x) > 0.2:
		var yaw := 0.0 if move_dir > 0.0 else PI
		gfx.rotation.y = lerp_angle(gfx.rotation.y, yaw, 10.0 * delta)
	# 爬行起伏 + 模型摆动
	gfx.position.y = absf(sin(state_t * 8.0)) * 0.05 * \
		clampf(absf(velocity.x), 0.0, 1.0)
	if model:
		gfx.rotation.z = sin(state_t * 9.0) * 0.05 * \
			clampf(absf(velocity.x), 0.0, 1.0)
