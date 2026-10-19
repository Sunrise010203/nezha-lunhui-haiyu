class_name EnemyShooter
extends EnemyBase
## 渊喉浮母：悬浮水母，保持距离并发射渊涡弹

var hover_y := 0.0
var range_min := 0.0
var range_max := 0.0
var _t := randf() * TAU
var shoot_cd := 1.5
var charging := 0.0
var core: MeshInstance3D
var core_mat: StandardMaterial3D
var _tentacles: Array[MeshInstance3D] = []


func _setup() -> void:
	max_hp = 40.0
	hp = max_hp
	uses_gravity = false
	collision_mask = 0
	rim_color = Color(0.78, 0.45, 1.0, 0.85)   # 紫边：一眼能看出是敌人
	add_hitbox(0.55, 1.2, 0.0)
	hover_y = global_position.y
	if range_max <= range_min:
		range_min = global_position.x - 4.0
		range_max = global_position.x + 4.0


const SPR_H := 1.7


var model: Node3D = null
var _mlight: OmniLight3D = null


func _build_gfx() -> void:
	model = Game.load_model("res://art/models/shooter.glb", 1.6, 0.0)
	if model:
		model.position.y = -0.8
		gfx.add_child(model)
		_mlight = OmniLight3D.new()
		_mlight.light_color = Color(0.7, 0.3, 1.0)
		_mlight.light_energy = 1.0
		_mlight.omni_range = 4.0
		_mlight.shadow_enabled = false
		gfx.add_child(_mlight)
		return
	var tex := Game.tex("res://art/sprites/shooter_idle.png")
	if tex:
		spr = make_sprite(tex, SPR_H, 0.05)
		var light2 := OmniLight3D.new()
		light2.light_color = Color(0.7, 0.3, 1.0)
		light2.light_energy = 1.0
		light2.omni_range = 4.0
		light2.shadow_enabled = false
		gfx.add_child(light2)
		return
	var bell_mat := Game.std_mat(Color(0.25, 0.12, 0.4, 0.85),
		Color(0.4, 0.15, 0.6), 0.7, 0.4)
	bell_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var bell := SphereMesh.new()
	bell.radius = 0.55
	bell.height = 1.1
	Game.add_mesh(gfx, bell, bell_mat, Vector3(0, 0.2, 0),
		Vector3.ZERO, Vector3(1.0, 0.85, 1.0))

	core_mat = Game.std_mat(Color(0.85, 0.4, 1.0), Color(0.8, 0.35, 1.0), 2.0, 0.3)
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.22
	core_mesh.height = 0.44
	core = Game.add_mesh(gfx, core_mesh, core_mat, Vector3(0, 0.1, 0))

	var tent_mat := Game.std_mat(Color(0.3, 0.15, 0.45),
		Color(0.35, 0.12, 0.5), 0.5, 0.5)
	var tent := CylinderMesh.new()
	tent.top_radius = 0.06
	tent.bottom_radius = 0.02
	tent.height = 0.9
	for i in 5:
		var a := TAU * i / 5.0
		var t := Game.add_mesh(gfx, tent, tent_mat,
			Vector3(cos(a) * 0.3, -0.45, sin(a) * 0.3))
		_tentacles.append(t)

	var light := OmniLight3D.new()
	light.light_color = Color(0.7, 0.3, 1.0)
	light.light_energy = 1.0
	light.omni_range = 4.0
	light.shadow_enabled = false
	gfx.add_child(light)


func _behave(delta: float) -> void:
	_t += delta
	# 悬浮起伏
	var target_y := hover_y + sin(_t * 1.8) * 0.35
	velocity.y = (target_y - global_position.y) * 4.0
	# 触须摆动 / 精灵与模型轻摆
	if spr or model:
		gfx.rotation.z = sin(_t * 1.6) * 0.07
	else:
		for i in _tentacles.size():
			_tentacles[i].rotation.x = sin(_t * 2.5 + i * 1.3) * 0.25
			_tentacles[i].rotation.z = cos(_t * 2.1 + i * 0.9) * 0.25

	if not player_alive():
		velocity.x = move_toward(velocity.x, 0.0, 6.0 * delta)
		return
	var d := dist_to_player()
	if d > 13.0:
		velocity.x = move_toward(velocity.x, 0.0, 6.0 * delta)
		_set_charge_visual(0.0)
		return

	# 与玩家保持 5~8 距离
	var dx := player.global_position.x - global_position.x
	var want := 0.0
	if absf(dx) < 4.0:
		want = -signf(dx) * 2.4
	elif absf(dx) > 8.0:
		want = signf(dx) * 2.0
	var next_x := global_position.x + signf(want) * 0.5
	if next_x < range_min or next_x > range_max:
		want = 0.0
	velocity.x = move_toward(velocity.x, want, 8.0 * delta)

	# 射击循环
	shoot_cd -= delta
	if shoot_cd <= 0.0:
		charging += delta
		_set_charge_visual(charging)
		if charging >= 0.55:
			_shoot()
			charging = 0.0
			shoot_cd = randf_range(2.0, 2.8)
			_set_charge_visual(0.0)
	# 面向玩家
	if spr:
		spr.flip_h = dx < 0.0
	else:
		var yaw := 0.0 if dx > 0.0 else PI
		gfx.rotation.y = lerp_angle(gfx.rotation.y, yaw, 6.0 * delta)


func _set_charge_visual(c: float) -> void:
	## 蓄力发光：精灵增亮放大 / 网格核心增亮 / 模型整体胀缩
	if spr:
		spr.modulate = Color(1.0 + c * 1.6, 1.0 + c * 0.8, 1.0 + c * 1.8)
		spr.set_meta("base_mod", spr.modulate)
		gfx.scale = Vector3.ONE * (1.0 + c * 0.12)
	elif core_mat:
		core_mat.emission_energy_multiplier = 2.0 + c * 7.0
		core.scale = Vector3.ONE * (1.0 + c * 0.8)
	else:
		gfx.scale = Vector3.ONE * (1.0 + c * 0.15)
		if _mlight:
			_mlight.light_energy = 1.0 + c * 4.0


func _shoot() -> void:
	if not player_alive():
		return
	Game.play_sfx("shoot", -8.0)
	var proj := Projectile.new()
	proj.dmg = 10.0
	var origin := global_position + Vector3(0, 0.1, 0)
	var target := player.global_position + Vector3(0, 0.9, 0)
	proj.vel = (target - origin).normalized() * 7.5
	proj.position = origin
	get_parent().add_child(proj)
	Game.burst(get_parent(), origin, Color(0.8, 0.35, 1.0), 8, 2.0, 0.05, 0.3)


func _on_hurt() -> void:
	# 受击打断蓄力
	charging = 0.0
	shoot_cd = maxf(shoot_cd, 0.6)
