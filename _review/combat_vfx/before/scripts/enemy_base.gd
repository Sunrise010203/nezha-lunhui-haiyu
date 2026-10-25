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
# 轮廓光（可读性）：深色敌人在深色背景里几乎看不见，加一圈菲涅尔边缘光
var rim_color := Color(0.4, 0.85, 1.0, 0.8)
var _rim: ShaderMaterial = null
var _stun_t := 0.0
var _fall_limit := -100.0   # 低于这个 y 视为坠渊死亡（由关卡 kill_y 推出）
var _no_drop := false
var enemy_motion: RefCounted

# ---- 第四章：可被「定潮 · 架」弹反的近战攻击窗口 ----
# 默认关闭，前三章的敌人一行逻辑都不会变；只有第四章的爬行者 / 潮生 / 螭吻会打开。
var parryable_melee := false
var _parry_window_t := 0.0
var _break_t := 0.0             # 「破绽」剩余时间（完美架命中后受伤 ×1.6）
const PARRY_STAGGER := 0.8      # 被架住后的僵直
const PARRY_COUNTER_DMG := 30.0
const PARRY_KNOCKBACK := 3.5


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
	# 关卡统一有 kill_y；敌人比玩家早一小段判定，避免坠到看不见的地方才消失
	var par := get_parent()
	if par and "kill_y" in par:
		_fall_limit = float(par.get("kill_y")) - 1.0
	_build_gfx()
	_setup()
	_apply_rim()
	Game.attach_blob_shadow(self, _blob_radius(), 0.55)


func _blob_radius() -> float:
	## 按碰撞体/ Boss 体型给接地影一个合理半径
	var r := 0.6
	for c in find_children("*", "CollisionShape3D", true, false):
		var sh := (c as CollisionShape3D).shape
		if sh is CapsuleShape3D:
			r = maxf(r, (sh as CapsuleShape3D).radius * 1.5)
		elif sh is BoxShape3D:
			r = maxf(r, (sh as BoxShape3D).size.x * 0.5)
	if max_hp >= 300.0:
		r = maxf(r, 1.8)
	return clampf(r, 0.5, 2.4)


func _apply_rim() -> void:
	if gfx == null:
		return
	_rim = Game.make_rim(rim_color)
	for mi: MeshInstance3D in gfx.find_children("*", "MeshInstance3D", true, false):
		mi.material_overlay = _rim


func set_rim_color(c: Color) -> void:
	## 供 Boss 换阶段时改变轮廓光颜色
	rim_color = c
	if _rim:
		_rim.set_shader_parameter("rim_color", c)


func _build_gfx() -> void:
	pass  # 子类实现


func load_enemy_model(asset: String, height: float, offset := 0.0, parent: Node3D = null) -> Node3D:
	var model := Game.load_model("res://art/models/enemies_arp/" + asset + ".glb",
		height, 90.0, 0.0, 0.0, true, false)
	if model:
		(parent if parent else gfx).add_child(model)
		model.position.y = offset
		enemy_motion = preload("res://scripts/enemy_motion.gd").new(model)
	return model


func _rig_animation() -> Array:
	return ["Move" if absf(velocity.x) > 0.2 else "Idle", -1.0]


func make_enemy_light(color: Color, at: Vector3) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.0
	light.omni_range = 3.6
	light.shadow_enabled = false
	light.position = at
	gfx.add_child(light)
	Game.tune_small_light(light, 0.35, 3.6)
	return light


func _advance_enemy_motion(delta: float) -> void:
	if not enemy_motion or dead:
		return
	var pose := _rig_animation()
	enemy_motion.step(delta, pose[0], pose[1], hurt_t > 0.0 or _stun_t > 0.0)


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
	# 掉出关卡（深渊）直接判定死亡：否则竞技场里"掉下悬崖的怪"永远不算死，
	# 封印墙不会打开，玩家无解只能重开。
	if global_position.y < _fall_limit:
		die_fall()
		return
	hurt_t = maxf(hurt_t - delta, 0.0)
	_parry_window_t = maxf(_parry_window_t - delta, 0.0)
	_break_t = maxf(_break_t - delta, 0.0)
	_tick_burn(delta)
	# 被混天绫束缚：暂停 AI，保留重力落地
	if _stun_t > 0.0:
		_stun_t = maxf(_stun_t - delta, 0.0)
		velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
		if uses_gravity and not is_on_floor():
			velocity.y -= 30.0 * delta
		move_and_slide()
		global_position.z = 0.0
		_advance_enemy_motion(delta)
		return
	if uses_gravity and not is_on_floor():
		velocity.y -= 30.0 * delta
	_behave(delta)
	move_and_slide()
	global_position.z = 0.0
	_advance_enemy_motion(delta)


func stun(dur: float) -> void:
	## 供混天绫等控制效果调用：暂停 AI 一段时间
	_stun_t = maxf(_stun_t, dur)
	hurt_t = maxf(hurt_t, dur)


# ---------------------------------------------------------------- 可弹近战窗口

func open_parry_window(dur := 0.35) -> void:
	## 敌人开始一段"可被架住"的攻击起手。只有 parryable_melee 的敌人才生效。
	if not parryable_melee or dead:
		return
	if _parry_window_t <= 0.0:
		# 起手三通道之一：红光 + 吸气音。读不到"起"就没有"架"可言。
		Game.flash_meshes(gfx, Color(1.0, 0.35, 0.3), 0.14)
		Game.play_sfx("tide", -13.0, 1.35)
	_parry_window_t = maxf(_parry_window_t, dur)


func parry_window_open() -> bool:
	return _parry_window_t > 0.0


func on_parried(from_x: float) -> void:
	## 被玩家「架」住：僵直 + 击退 + 反震伤害
	_parry_window_t = 0.0
	var dir := signf(global_position.x - from_x)
	if dir == 0.0:
		dir = 1.0
	stun(PARRY_STAGGER)
	Game.burst(get_parent(), global_position + Vector3(0, 1.0, 0),
		Color(0.85, 0.95, 0.9, 0.9), 18, 5.0, 0.08, 0.5)
	take_damage(PARRY_COUNTER_DMG, dir, false)
	velocity.x = dir * PARRY_KNOCKBACK * 2.6 * (1.0 - knock_resist)


func open_break(dur := 1.5) -> void:
	## 完美架命中：敌人显露「破绽」，期间受伤 ×1.3
	_break_t = maxf(_break_t, dur)
	Game.spawn_dmg_text(get_parent(), global_position + Vector3(0, 2.0, 0),
		"破绽", Color(0.95, 0.9, 0.75), true)


func is_broken() -> bool:
	return _break_t > 0.0


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
	if _break_t > 0.0:
		dmg *= 1.6
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


func die_fall() -> void:
	## 坠渊死亡：不掉落（道具会掉在深渊里）、但必须发 enemy_died 让竞技场计数
	_no_drop = true
	die()


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
	# 掉落灵力珠（坠渊时不掉）
	if not _no_drop:
		var n := randi_range(2, 3)
		for i in n:
			var orb := Pickup.new()
			orb.kind = Pickup.Kind.ENERGY
			orb.position = global_position + Vector3(randf_range(-0.5, 0.5),
				0.8 + randf_range(0.0, 0.5), 0)
			get_parent().add_child(orb)
	enemy_died.emit(self)
	queue_free()
