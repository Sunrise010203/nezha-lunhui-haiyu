class_name EnemySpawnling
extends EnemyBase
## 潮生：龙骨沉殿里新生的近战怪。纯扑咬型，起手 0.4s，**这一下可以被「架」住**。
## 它是第四章"近战弹反"的主力教具：动作大、起手长、血薄，适合被打断。

const WINDUP := 0.40
const LUNGE_V := 10.0
const PARRY_WINDOW := 0.7

var patrol_min := 0.0
var patrol_max := 0.0
var state := "patrol"
var state_t := 0.0
var move_dir := 1.0
var lunge_cd := 0.0
var _contact_cd := 0.0
var _shell := true      # 潮甲：未架住之前，硬砍收益减半（逼玩家用「架」拆甲）

var model: Node3D = null


func _setup() -> void:
	max_hp = 40.0
	hp = max_hp
	touch_damage = 10.0
	parryable_melee = true
	rim_color = Color(0.45, 0.95, 0.80, 0.9)   # 玉青边：和潮脉同色系，暗示"可弹"
	add_hitbox(0.42, 0.95, 0.47)
	if patrol_max <= patrol_min:
		patrol_min = global_position.x - 2.5
		patrol_max = global_position.x + 2.5


func take_damage(dmg: float, dir: float, heavy := false) -> void:
	if _shell and not dead:
		dmg *= 0.5
		Game.spawn_dmg_text(get_parent(), global_position + Vector3(0, 1.35, 0),
			"潮甲", Color(0.45, 0.88, 0.92))
	super.take_damage(dmg, dir, heavy)


func on_parried(from_x: float) -> void:
	# 架住 = 甲碎：这一下之后才是"真正能砍动"的窗口
	_shell = false
	super.on_parried(from_x)


func _build_gfx() -> void:
	model = load_enemy_model("008_spawnling", 0.95)
	if not model:
		model = Game.load_model("res://art/models/crawler.glb", 0.95, 180.0)
	if model:
		if not model.get_parent():
			gfx.add_child(model)
		var ml := OmniLight3D.new()
		ml.light_color = Color(0.35, 0.95, 0.8)
		ml.light_energy = 0.7
		ml.omni_range = 2.6
		ml.position = Vector3(0, 0.55, 0.4)
		ml.shadow_enabled = false
		gfx.add_child(ml)
		Game.tune_small_light(ml, 0.3, 3.0)
		return
	# 兜底：程序化小水母
	var body_mat := Game.std_mat(Color(0.12, 0.32, 0.30),
		Color(0.08, 0.35, 0.32), 0.6, 0.5)
	var body := SphereMesh.new()
	body.radius = 0.45
	body.height = 0.9
	Game.add_mesh(gfx, body, body_mat, Vector3(0, 0.45, 0),
		Vector3.ZERO, Vector3(1.1, 0.8, 1.0))
	var eye_mat := Game.std_mat(Color(0.5, 1.0, 0.85), Color(0.4, 1.0, 0.8),
		2.4, 0.3)
	var eye := SphereMesh.new()
	eye.radius = 0.07
	eye.height = 0.14
	Game.add_mesh(gfx, eye, eye_mat, Vector3(0.42, 0.52, 0.14))
	Game.add_mesh(gfx, eye, eye_mat, Vector3(0.42, 0.52, -0.14))


func _behave(delta: float) -> void:
	state_t += delta
	lunge_cd = maxf(lunge_cd - delta, 0.0)
	_contact_cd = maxf(_contact_cd - delta, 0.0)
	var d := dist_to_player()
	var dy := absf(player.global_position.y - global_position.y) \
		if player_alive() else 99.0

	match state:
		"patrol":
			velocity.x = move_toward(velocity.x, move_dir * 2.4, 12.0 * delta)
			if global_position.x > patrol_max:
				move_dir = -1.0
			elif global_position.x < patrol_min:
				move_dir = 1.0
			if d < 7.0 and dy < 2.4:
				state = "chase"
				state_t = 0.0
		"chase":
			if not player_alive() or d > 10.0:
				state = "patrol"
				return
			var dir := signf(player.global_position.x - global_position.x)
			move_dir = dir if dir != 0.0 else move_dir
			var next_x := global_position.x + move_dir * 0.6
			if next_x > patrol_min - 0.6 and next_x < patrol_max + 0.6:
				velocity.x = move_toward(velocity.x, move_dir * 5.0, 16.0 * delta)
			else:
				velocity.x = move_toward(velocity.x, 0.0, 16.0 * delta)
			if d < 2.4 and dy < 1.7 and lunge_cd <= 0.0:
				state = "windup"
				state_t = 0.0
				velocity.x = 0.0
				# 起手三通道：下蹲蓄势 + 红光 + 吸气音（open_parry_window 负责红闪与音效）
				open_parry_window(PARRY_WINDOW)
				if not enemy_motion:
					var tw := gfx.create_tween()
					tw.tween_property(gfx, "scale", Vector3(0.88, 0.78, 0.88), WINDUP)
		"windup":
			velocity.x = move_toward(velocity.x, 0.0, 22.0 * delta)
			if state_t >= WINDUP:
				state = "lunge"
				state_t = 0.0
				velocity.x = move_dir * LUNGE_V
				velocity.y = 3.0
				if not enemy_motion:
					var tw := gfx.create_tween()
					tw.tween_property(gfx, "scale", Vector3(1.25, 0.75, 1.05), 0.1)
					tw.tween_property(gfx, "scale", Vector3.ONE, 0.22)
				Game.play_sfx("swing", -9.0, 0.75)
		"lunge":
			velocity.x = move_toward(velocity.x, 0.0, 9.0 * delta)
			if d < 1.8 and _contact_cd <= 0.0 and player_alive():
				_contact_cd = 0.8
				if parry_window_open() and player.try_parry_melee(self):
					state = "recover"
					state_t = 0.0
				else:
					player.take_damage(touch_damage, global_position.x)
			if state_t >= 0.45:
				state = "recover"
				state_t = 0.0
		"recover":
			velocity.x = move_toward(velocity.x, 0.0, 14.0 * delta)
			if state_t >= 0.3:
				state = "chase"
				lunge_cd = 1.5
		_:
			state = "patrol"

	# 朝向 + 轻微起伏
	if absf(velocity.x) > 0.2:
		var yaw := 0.0 if move_dir > 0.0 else PI
		gfx.rotation.y = lerp_angle(gfx.rotation.y, yaw, 10.0 * delta)
	if enemy_motion:
		return
	gfx.position.y = sin(state_t * 7.0) * 0.03 * \
		clampf(absf(velocity.x), 0.0, 1.0)


func _rig_animation() -> Array:
	if state == "windup":
		return ["Windup", state_t / WINDUP]
	if state == "lunge":
		return ["Attack", state_t / 0.45]
	if state == "recover":
		return ["Recover", state_t / 0.3]
	return super._rig_animation()
