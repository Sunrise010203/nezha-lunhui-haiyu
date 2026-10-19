class_name Pickup
extends Area3D
## 拾取物：灵力珠 / 回春莲

enum Kind { ENERGY, HEAL, SOUL }

var kind := Kind.ENERGY
var _t := randf() * TAU
var _magnet_target: Player = null
var _base_y := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var col := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.6
	col.shape = sph
	add_child(col)
	_base_y = position.y

	match kind:
		Kind.ENERGY:
			var m := SphereMesh.new()
			m.radius = 0.13
			m.height = 0.26
			var c := Color(0.35, 0.9, 0.9)
			Game.add_mesh(self, m, Game.std_mat(c, c, 2.2, 0.3), Vector3.ZERO)
		Kind.HEAL:
			# 莲花：中心 + 花瓣
			var c := Color(0.45, 1.0, 0.6)
			var core := SphereMesh.new()
			core.radius = 0.14
			core.height = 0.28
			Game.add_mesh(self, core, Game.std_mat(Color(1.0, 0.9, 0.5),
				Color(1.0, 0.8, 0.3), 1.8, 0.4), Vector3.ZERO)
			var petal := SphereMesh.new()
			petal.radius = 0.1
			petal.height = 0.2
			var pm := Game.std_mat(Color(0.55, 0.95, 0.65),
				Color(0.2, 0.65, 0.35), 0.5, 0.5)
			for i in 6:
				var a := TAU * i / 6.0
				Game.add_mesh(self, petal, pm,
					Vector3(cos(a) * 0.2, -0.05, sin(a) * 0.2),
					Vector3.ZERO, Vector3(1.4, 0.5, 1.0))
			var light := OmniLight3D.new()
			light.light_color = c
			light.light_energy = 0.9
			light.omni_range = 2.5
			light.shadow_enabled = false
			add_child(light)
			Game.tune_small_light(light, 0.45, 2.8)
		Kind.SOUL:
			# 龙魂残片：鎏金龙珠 + 旋转金环
			var gold := Color(1.0, 0.82, 0.35)
			var core := SphereMesh.new()
			core.radius = 0.22
			core.height = 0.44
			Game.add_mesh(self, core, Game.std_mat(gold, gold, 2.4, 0.25, 0.7),
				Vector3.ZERO)
			var ring_m := TorusMesh.new()
			ring_m.inner_radius = 0.32
			ring_m.outer_radius = 0.37
			Game.add_mesh(self, ring_m,
				Game.std_mat(Color(0.95, 0.6, 0.2), Color(0.9, 0.5, 0.15),
					1.6, 0.3), Vector3.ZERO, Vector3(24, 0, 12))
			var light := OmniLight3D.new()
			light.light_color = gold
			light.light_energy = 1.4
			light.omni_range = 4.0
			light.shadow_enabled = false
			add_child(light)
			Game.tune_small_light(light, 0.65, 3.4)

	body_entered.connect(_on_body)


func _process(delta: float) -> void:
	_t += delta
	if _magnet_target and is_instance_valid(_magnet_target):
		var to := _magnet_target.global_position + Vector3(0, 0.9, 0)
		global_position = global_position.lerp(to, 10.0 * delta)
		if global_position.distance_to(to) < 0.4:
			_collect()
	else:
		position.y = _base_y + sin(_t * 2.2) * 0.12
		rotation.y += delta * 1.6
		# 靠近时被吸引
		var p := get_tree().get_first_node_in_group("player") as Player
		if p and p.act != "dead" \
				and global_position.distance_to(p.global_position) < 2.2:
			_magnet_target = p


func _on_body(body: Node3D) -> void:
	if body is Player:
		_magnet_target = body


func _collect() -> void:
	var p := _magnet_target
	if p == null:
		return
	match kind:
		Kind.ENERGY:
			p.add_energy(12.0)
			Game.play_sfx("orb", -10.0)
			Game.burst(get_parent(), global_position, Color(0.35, 0.9, 0.9),
				8, 2.5, 0.05, 0.35)
		Kind.HEAL:
			p.heal(25.0)
			Game.play_sfx("pickup", -6.0)
			Game.burst(get_parent(), global_position, Color(0.45, 1.0, 0.6),
				16, 4.0, 0.08, 0.5)
		Kind.SOUL:
			Game.collect_soul()
			Game.play_sfx("checkpoint", -2.0, 1.2)
			Game.burst(get_parent(), global_position, Color(1.0, 0.82, 0.35),
				28, 6.0, 0.1, 0.8)
	queue_free()
