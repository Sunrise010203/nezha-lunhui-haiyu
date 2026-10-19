class_name EnemyBase
extends CharacterBody3D
## 敌人基类：生命 / 受击 / 击退 / 灼烧 / 死亡掉落

signal enemy_died(enemy: EnemyBase)

const L_WORLD := 1
const L_ENEMY_LAYER := 4

var max_hp := 50.0
var hp := 50.0
var touch_damage := 12.0
var uses_gravity := true
var knock_resist := 0.0      # 0~1，Boss 接近 1
var gfx: Node3D
var dead := false
var hurt_t := 0.0
var _burn_left := 0.0
var _burn_tick := 0.0
var player: Player
# AI 立绘精灵模式
var spr: Sprite3D = null


func make_sprite(tex: Texture2D, height: float, y_center: float) -> Sprite3D:
	## 创建 AI 立绘精灵（替代程序化网格）
	var s := Sprite3D.new()
	s.texture = tex
	s.pixel_size = height / float(tex.get_height())
	s.position.y = y_center
	s.shaded = false
	gfx.add_child(s)
	return s


func set_sprite_tex(tex: Texture2D, height: float) -> void:
	if spr and tex and spr.texture != tex:
		spr.texture = tex
		spr.pixel_size = height / float(tex.get_height())


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = L_ENEMY_LAYER
	collision_mask = L_WORLD if uses_gravity else 0
	gfx = Node3D.new()
	add_child(gfx)
	player = get_tree().get_first_node_in_group("player") as Player
	_build_gfx()
	_setup()


func _build_gfx() -> void:
	pass  # 子类实现


func _setup() -> void:
	pass  # 子类实现


func add_hitbox(radius: float, height: float, y := 0.0) -> void:
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = radius
	cap.height = height
	col.shape = cap
	col.position.y = y
	add_child(col)


func _physics_process(delta: float) -> void:
	if dead:
		return
	hurt_t = maxf(hurt_t - delta, 0.0)
	_tick_burn(delta)
	if uses_gravity and not is_on_floor():
		velocity.y -= 30.0 * delta
	_behave(delta)
	move_and_slide()
	global_position.z = 0.0


func _behave(_delta: float) -> void:
	pass  # 子类实现


func player_alive() -> bool:
	return player != null and is_instance_valid(player) and player.act != "dead"


func dist_to_player() -> float:
	if not player_alive():
		return 9999.0
	return global_position.distance_to(player.global_position)


func _tick_burn(delta: float) -> void:
	if _burn_left <= 0.0:
		return
	_burn_tick -= delta
	if _burn_tick <= 0.0:
		_burn_tick = 0.5
		var d := minf(2.5, _burn_left)
		_burn_left -= d
		hp -= d
		Game.burst(get_parent(), global_position + Vector3(0, 0.8, 0),
			Color(1.0, 0.5, 0.1), 6, 2.0, 0.06, 0.4)
		if hp <= 0.0:
			die()


func apply_burn(total: float) -> void:
	_burn_left = maxf(_burn_left, total)
	_burn_tick = 0.4


func take_damage(dmg: float, dir: float, heavy := false) -> void:
	if dead:
		return
	hp -= dmg
	hurt_t = 0.22
	var knock := (10.0 if heavy else 5.0) * (1.0 - knock_resist)
	velocity.x = dir * knock
	if uses_gravity and heavy:
		velocity.y = 3.5
	Game.flash_meshes(gfx)
	Game.spawn_dmg_text(get_parent(), global_position + Vector3(0, 1.6, 0),
		str(int(dmg)), Color(1.0, 0.85, 0.4) if not heavy else Color(1.0, 0.6, 0.15),
		heavy)
	_on_hurt()
	if hp <= 0.0:
		die()


func _on_hurt() -> void:
	pass  # 子类可重写


func die() -> void:
	if dead:
		return
	dead = true
	# 击杀回灵
	if player_alive():
		player.add_energy(15.0)
	Game.play_sfx("enemy_die", -5.0)
	Game.burst(get_parent(), global_position + Vector3(0, 0.8, 0),
		Color(0.45, 0.2, 0.55), 30, 7.0, 0.1, 0.7)
	Game.burst(get_parent(), global_position + Vector3(0, 0.8, 0),
		Color(0.2, 0.7, 0.7), 16, 5.0, 0.08, 0.5)
	# 掉落灵力珠
	var n := randi_range(2, 3)
	for i in n:
		var orb := Pickup.new()
		orb.kind = Pickup.Kind.ENERGY
		orb.position = global_position + Vector3(randf_range(-0.5, 0.5),
			0.8 + randf_range(0.0, 0.5), 0)
		get_parent().add_child(orb)
	enemy_died.emit(self)
	queue_free()
