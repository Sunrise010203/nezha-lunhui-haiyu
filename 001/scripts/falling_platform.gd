class_name FallingPlatform
extends AnimatableBody3D
## 碎裂浮桥：踩上后震颤、坠落，随后重组

var width := 2.4
var state := "idle"   # idle / shake / fall / gone
var t := 0.0
var orig_pos := Vector3.ZERO
var fall_v := 0.0
var _col: CollisionShape3D
var _trim_mat: StandardMaterial3D
var _gfx: Node3D


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	sync_to_physics = false
	orig_pos = position

	_col = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, 0.5, 4.0)
	_col.shape = box
	add_child(_col)

	_gfx = Node3D.new()
	add_child(_gfx)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, 0.5, 4.0)
	var mat := Game.std_mat(Color(0.13, 0.2, 0.26), Color(0.02, 0.05, 0.06),
		0.3, 0.85)
	Game.add_mesh(_gfx, mesh, mat, Vector3.ZERO)
	# 发光描边
	var trim := BoxMesh.new()
	trim.size = Vector3(width, 0.06, 0.1)
	_trim_mat = Game.std_mat(Color(0.3, 0.8, 0.8), Color(0.25, 0.75, 0.75),
		1.4, 0.4)
	Game.add_mesh(_gfx, trim, _trim_mat, Vector3(0, 0.26, 2.0))

	# 顶面感应区
	var sensor := Area3D.new()
	sensor.collision_layer = 0
	sensor.collision_mask = 2
	var scs := CollisionShape3D.new()
	var sbox := BoxShape3D.new()
	sbox.size = Vector3(width, 0.6, 4.0)
	scs.shape = sbox
	scs.position.y = 0.5
	sensor.add_child(scs)
	add_child(sensor)
	sensor.body_entered.connect(func(b: Node3D) -> void:
		if b is Player and state == "idle":
			state = "shake"
			t = 0.0
			Game.play_sfx("gate", -14.0, 2.0))


func _physics_process(delta: float) -> void:
	match state:
		"shake":
			t += delta
			_gfx.position.x = sin(t * 50.0) * 0.05
			_gfx.position.y = sin(t * 63.0) * 0.03
			_trim_mat.emission = Color(1.0, 0.4, 0.3)
			_trim_mat.emission_energy_multiplier = 2.0 + sin(t * 30.0)
			if t >= 0.5:
				state = "fall"
				t = 0.0
				fall_v = 0.0
				_gfx.position = Vector3.ZERO
		"fall":
			t += delta
			fall_v += 22.0 * delta
			position.y -= fall_v * delta
			_gfx.rotation.z += delta * 0.8
			if t > 0.35:
				_col.set_deferred("disabled", true)
			if position.y < orig_pos.y - 14.0:
				state = "gone"
				t = 0.0
				visible = false
		"gone":
			t += delta
			if t >= 2.8:
				_respawn()


func _respawn() -> void:
	state = "idle"
	position = orig_pos
	_gfx.rotation.z = 0.0
	_gfx.position = Vector3.ZERO
	fall_v = 0.0
	visible = true
	_col.set_deferred("disabled", false)
	_trim_mat.emission = Color(0.25, 0.75, 0.75)
	_trim_mat.emission_energy_multiplier = 1.4
	Game.burst(get_parent(), position, Color(0.3, 0.8, 0.8), 10, 2.0, 0.06, 0.4)
