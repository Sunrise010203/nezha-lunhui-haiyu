class_name Projectile
extends Area3D
## 敌方投射物：渊涡弹

var vel := Vector3.ZERO
var dmg := 10.0
var life := 5.0
var tint := Color(0.75, 0.3, 0.95)


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 2  # 地形 + 玩家
	monitoring = true
	var col := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.28
	col.shape = sph
	add_child(col)

	var mesh := SphereMesh.new()
	mesh.radius = 0.2
	mesh.height = 0.4
	var mat := Game.std_mat(tint, tint, 2.6, 0.3)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	Game.add_mesh(self, mesh, mat, Vector3.ZERO)
	var core := SphereMesh.new()
	core.radius = 0.1
	core.height = 0.2
	Game.add_mesh(self, core, Game.std_mat(Color.WHITE, Color.WHITE, 3.0),
		Vector3.ZERO)

	var light := OmniLight3D.new()
	light.light_color = tint
	light.light_energy = 1.2
	light.omni_range = 3.0
	light.shadow_enabled = false
	add_child(light)

	body_entered.connect(_on_body)


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		_pop()
		return
	global_position += vel * delta
	rotation.z += delta * 6.0


func _on_body(body: Node3D) -> void:
	if body is Player:
		(body as Player).take_damage(dmg, global_position.x)
		_pop()
	elif body is StaticBody3D or body is AnimatableBody3D:
		_pop()


func _pop() -> void:
	if not is_inside_tree():
		return
	Game.burst(get_parent(), global_position, tint, 10, 3.0, 0.06, 0.4)
	queue_free()
