class_name Projectile
extends Area3D
## 投射物：敌方「渊涡弹 / 潮珠」与玩家「定潮」反弹回来的潮弹共用这一个类。
##
## 第四章新增：team（敌/我）、可弹（parryable）、浊潮（is_muddy）、反射（reflect）。
## 默认值保持旧行为：team = 敌方、可弹、命中玩家造成伤害，所以前三章不需要改任何代码。

const TEAM_ENEMY := 1
const TEAM_PLAYER := 2

var vel := Vector3.ZERO
var dmg := 10.0
var life := 5.0
var tint := Color(0.75, 0.3, 0.95)

var team := TEAM_ENEMY            # 1 = 敌人弹幕 / 2 = 我方的弹（反弹或齐射）
var parryable := true             # 可被「定潮 · 卸」反弹
var is_muddy := false             # 浊潮：不可弹、不可吸
var was_reflected := false        # 由弹反产生（潮纹碑只认这种）
var homing := 0.0                 # 轻微追踪强度（反弹后才有）
var homing_target: Node3D = null
var source: Node3D = null         # 谁打的（用于反弹方向/归属）
var held := false                 # 被「引潮」吸住时悬停（无害）

var _light: OmniLight3D
var _core: MeshInstance3D
var _mat: StandardMaterial3D


func _ready() -> void:
	add_to_group("projectiles")
	_apply_team_mask()
	monitoring = true
	var col := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.28
	col.shape = sph
	add_child(col)

	var mesh := SphereMesh.new()
	mesh.radius = 0.2
	mesh.height = 0.4
	_mat = Game.std_mat(tint, tint, 2.6, 0.3)
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	Game.add_mesh(self, mesh, _mat, Vector3.ZERO)
	_core = Game.add_mesh(self, mesh, Game.std_mat(Color.WHITE, Color.WHITE, 3.0),
		Vector3.ZERO)
	_core.scale = Vector3(0.5, 0.5, 0.5)
	if is_muddy:
		_build_muddy_marks()

	_light = OmniLight3D.new()
	_light.light_color = tint
	_light.light_energy = 1.2
	_light.omni_range = 3.0
	_light.shadow_enabled = false
	add_child(_light)
	Game.tune_small_light(_light, 0.55, 2.6)
	if is_muddy:
		# 浊潮不长灯：省 draw call，也让"不可弹"在视觉上更闷
		_light.visible = false

	body_entered.connect(_on_body)


func _build_muddy_marks() -> void:
	## 浊潮 = 暗红实心 + 一圈黑刻痕（用 1 个环 + 1 个暗色外壳表达，不加 draw call）
	var torus := TorusMesh.new()
	torus.inner_radius = 0.24
	torus.outer_radius = 0.3
	torus.rings = 12
	torus.ring_segments = 4
	var dark := Game.std_mat(Color(0.06, 0.03, 0.03), Color(0.0, 0.0, 0.0), 0.0)
	Game.add_mesh(self, torus, dark, Vector3.ZERO)
	_core.visible = false
	if _mat:
		_mat.emission_energy_multiplier = 0.6
		_mat.albedo_color = Color(0.42, 0.08, 0.08)


func _apply_team_mask() -> void:
	if team == TEAM_PLAYER:
		collision_layer = 0
		collision_mask = 1 | 4   # 地形 + 敌人（4）
	else:
		collision_layer = 0
		collision_mask = 1 | 2   # 地形 + 玩家（2）


func _physics_process(delta: float) -> void:
	if held:
		return                     # 被引潮吸住：悬停、不移动、不判定
	life -= delta
	if life <= 0.0:
		_pop()
		return
	if homing > 0.0 and homing_target != null and is_instance_valid(homing_target):
		var want := (homing_target.global_position - global_position).normalized()
		vel = vel.lerp(want * vel.length(), clampf(homing * delta * 8.0, 0.0, 1.0))
	global_position += vel * delta
	rotation.z += delta * 6.0


func _on_body(body: Node3D) -> void:
	if team == TEAM_PLAYER:
		# 我方的弹：打敌人 / 点亮潮纹碑 / 撞地形消失
		if body.is_in_group("tide_stele") and body.has_method("light_up"):
			if was_reflected:
				body.light_up()
			_pop()
			return
		if body.has_method("take_damage") and not (body is Player):
			body.take_damage(dmg, signf(vel.x), false)
			_pop()
			return
		if body is StaticBody3D or body is AnimatableBody3D:
			_pop()
		return

	# 敌方的弹
	if body is Player:
		var p := body as Player
		if parryable and not is_muddy and p.has_method("try_parry_projectile") \
				and p.try_parry_projectile(self):
			return
		p.take_damage(dmg, global_position.x)
		_pop()
	elif body is StaticBody3D or body is AnimatableBody3D:
		_pop()


func reflect(dir: float, new_dmg: float, owner_player: Node3D = null) -> void:
	## 被「卸」回来的潮弹：改成我方弹，反向飞回去，带一点追踪
	if not is_inside_tree():
		return
	team = TEAM_PLAYER
	was_reflected = true
	parryable = false
	dmg = new_dmg
	source = owner_player
	life = maxf(life, 2.6)
	var spd := maxf(vel.length(), 14.0)
	vel = Vector3(dir * spd, 0.6, 0.0)
	homing = 0.18
	homing_target = _nearest_enemy()
	_apply_team_mask()
	_restyle_for_player()


func hold() -> void:
	## 「引潮」吸附：悬停、无害（关掉碰撞检测）
	held = true
	monitoring = false
	vel = Vector3.ZERO
	if _core:
		_core.visible = true
	if _mat:
		_mat.albedo_color = Color(0.42, 0.95, 0.86)
		_mat.emission = Color(0.42, 0.95, 0.86)
		_mat.emission_energy_multiplier = 2.4


func resume() -> void:
	## 被打断（冲刺取消引潮）时把吸住的弹放回原样
	held = false
	monitoring = true
	_apply_team_mask()
	vel = Vector3(-12.0, 0.0, 0.0)


func volley(dirx: float, ang: float, new_dmg: float) -> void:
	## 齐射：松开引潮时把吸附的弹一起打出去（归我方，但不点亮潮纹碑）
	if not is_inside_tree():
		return
	team = TEAM_PLAYER
	was_reflected = false
	parryable = false
	held = false
	monitoring = true
	dmg = new_dmg
	source = null
	life = 2.4
	vel = Vector3(dirx * cos(ang) * 22.0, sin(ang) * 7.0, 0.0)
	homing = 0.10
	homing_target = _nearest_enemy()
	_apply_team_mask()
	_restyle_for_player()


func _restyle_for_player() -> void:
	## 转玉青 + 白心更亮（"这枚现在是我的"）
	var jade := Color(0.42, 0.95, 0.86)
	if _mat:
		_mat.albedo_color = jade
		_mat.emission = jade
		_mat.emission_energy_multiplier = 3.0
	if _core:
		_core.visible = true
	if _light:
		_light.visible = true
		_light.light_color = jade
	_trail_on()


func _trail_on() -> void:
	var g := GPUParticles3D.new()
	g.amount = 12
	g.lifetime = 0.22
	g.one_shot = false
	g.emitting = true
	g.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.ZERO
	pm.spread = 180.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.8
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.2
	pm.scale_max = 0.4
	pm.color = Color(0.42, 0.95, 0.86, 0.8)
	g.process_material = pm
	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	var m := Game.std_mat(Color(0.42, 0.95, 0.86), Color(0.42, 0.95, 0.86), 2.4)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = m
	g.draw_pass_1 = mesh
	add_child(g)


func _nearest_enemy() -> Node3D:
	var best: Node3D = null
	var bd := 18.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Node3D and is_instance_valid(e):
			var d: float = (e as Node3D).global_position.distance_to(global_position)
			if d < bd:
				bd = d
				best = e
	return best


func _pop() -> void:
	if not is_inside_tree():
		return
	var c := tint
	if was_reflected:
		c = Color(0.42, 0.95, 0.86)
	Game.burst(get_parent(), global_position, c, 10, 3.0, 0.06, 0.4)
	queue_free()
