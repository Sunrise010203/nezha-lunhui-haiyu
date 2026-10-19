class_name RingThrow
extends Node3D
## 乾坤圈投掷：飞出贯穿敌人后回旋归手，去程与回程各判定一次

const L_ENEMY := 4
const OUT_SPEED := 16.0
const BACK_SPEED := 19.0
const MAX_DIST := 8.5

var owner_player: Player
var dir := 1.0
var dmg := 16.0
var max_dist := 8.5          # 由蓄力决定：点按 8.5，蓄满 16.5

var _state := "out"
var _start_x := 0.0
var _seen := {}
var _life := 5.0


func _ready() -> void:
	_start_x = global_position.x
	var torus := TorusMesh.new()
	torus.inner_radius = 0.42
	torus.outer_radius = 0.52
	var gold := Color(0.95, 0.75, 0.3)
	var mat := Game.std_mat(gold, gold, 2.4, 0.25, 0.9)
	Game.add_mesh(self, torus, mat, Vector3.ZERO, Vector3(90, 0, 0))
	var light := OmniLight3D.new()
	light.light_color = gold
	light.light_energy = 1.4
	light.omni_range = 3.5
	light.shadow_enabled = false
	add_child(light)
	# 金色流光
	var p := GPUParticles3D.new()
	p.amount = 14
	p.lifetime = 0.4
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.8
	pm.gravity = Vector3.ZERO
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.5
	pm.color = Color(1.0, 0.85, 0.4, 0.6)
	p.process_material = pm
	var dm := SphereMesh.new()
	dm.radius = 0.04
	dm.height = 0.08
	dm.radial_segments = 4
	dm.rings = 2
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(1.0, 0.9, 0.5, 0.7)
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.material = dmat
	p.draw_pass_1 = dm
	add_child(p)


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		_finish()
		return
	rotation.z += 18.0 * delta
	match _state:
		"out":
			global_position.x += dir * OUT_SPEED * delta
			_damage_sweep()
			if absf(global_position.x - _start_x) >= max_dist:
				_state = "back"
				_seen.clear()
		"back":
			if owner_player == null or not is_instance_valid(owner_player):
				queue_free()
				return
			var to := owner_player.global_position + Vector3(0, 1.1, 0)
			var diff := to - global_position
			var d := diff.length()
			if d < 0.7:
				_finish()
				return
			global_position += diff / d * BACK_SPEED * delta
			_damage_sweep()


func _damage_sweep() -> void:
	var space := get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.85
	q.shape = shape
	q.transform = Transform3D(Basis(), global_position)
	q.collision_mask = L_ENEMY
	q.collide_with_areas = true
	q.collide_with_bodies = true
	for h in space.intersect_shape(q, 12):
		var c: Object = h.collider
		if c == null or _seen.has(c) or not c.has_method("take_damage"):
			continue
		_seen[c] = true
		var kdir := dir
		if c is Node3D and owner_player and is_instance_valid(owner_player):
			kdir = signf((c as Node3D).global_position.x -
				owner_player.global_position.x)
			if kdir == 0.0:
				kdir = dir
		c.take_damage(dmg, kdir, false)
		# 控制：普通敌人被乾坤圈打断 0.5 秒；Boss / 大型目标免疫
		var is_boss := c.has_method("reset_fight") \
			or float(c.get("max_hp") if c.get("max_hp") != null else 0.0) >= 150.0
		if not is_boss and c.has_method("stun") and not bool(c.get("dead")):
			c.call("stun", 0.5)
		if owner_player and is_instance_valid(owner_player):
			owner_player.add_energy(6.0)
			owner_player.register_hit(1)
		Game.play_sfx("hit", -8.0, 1.3)
		Game.burst(get_parent(), global_position, Color(1.0, 0.85, 0.4),
			10, 3.5, 0.06, 0.4)


func _finish() -> void:
	if owner_player and is_instance_valid(owner_player):
		owner_player.ring_returned()
		Game.play_sfx("orb", -8.0, 0.8)
	queue_free()
