extends SceneTree

class Dummy extends StaticBody3D:
	var damage := 0.0
	var burn := 0.0
	func take_damage(amount: float, _dir: float, _heavy := false) -> void:
		damage += amount
	func apply_burn(amount: float) -> void:
		burn += amount

var failed := false
var checks: Array[String] = []
func check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error(label)
	else:
		checks.append(label)
		print("PASS ", label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var actor = load("res://scripts/player.gd").new()
	stage.add_child(actor)
	actor.set_physics_process(false)
	actor._start_action("atk1")
	actor.act_t = 0.11
	actor._process_action()
	check(get_node_count_in_group("combat_vfx_transient") == 1, "missed attack still emits one slash")
	actor._process_action()
	check(get_node_count_in_group("combat_vfx_transient") == 1, "attack emits once per hit window")
	var right: Node3D = get_nodes_in_group("combat_vfx_transient")[0]
	CombatVFX.slash(stage, actor.position, -1)
	var left: Node3D = get_nodes_in_group("combat_vfx_transient")[1]
	check(left.basis.x.normalized().dot(right.basis.x.normalized()) < -0.99, "left slash mirrors right slash")
	var dummy := Dummy.new()
	dummy.collision_layer = 4
	dummy.collision_mask = 0
	dummy.position = Vector3(1.2, 1, 0)
	var col := CollisionShape3D.new()
	col.shape = BoxShape3D.new()
	dummy.add_child(col)
	stage.add_child(dummy)
	await physics_frame
	await physics_frame
	actor.energy = 0
	actor._strike(10, Vector3(2.4,1.8,2), Vector3(1.25,.95,0), 4)
	check(dummy.damage == 10 and actor.energy == 10, "light hit damage and energy unchanged")
	actor._strike(30, Vector3(3.4,2.4,2.6), Vector3(1.5,1,0), 11, true)
	check(dummy.damage == 40 and actor.energy == 28, "heavy hit damage and energy unchanged")
	actor._do_nova()
	check(dummy.damage == 80 and dummy.burn == 15, "nova damage and burn unchanged")
	actor.energy = 100
	root.get_node("Game").skills["V"] = true
	actor._cast_wheel()
	check(actor.energy == 40, "wind wheel still costs 60 energy")
	actor._build_tide_fx()
	actor._guard_blend = 1
	actor._update_tide_fx(0)
	check(actor._tide_fx.size() == 2 and actor._tide_fx[0].visible and actor._tide_fx[1].visible, "water shell and rune appear")
	var projectile = load("res://scripts/projectile.gd").new()
	projectile.position = Vector3(1,1,0)
	stage.add_child(projectile)
	projectile.set_physics_process(false)
	actor._tide_guard_t = actor.TIDE_PARRY_WINDOW
	actor._tide_reuse_t = 0
	check(actor.try_parry_projectile(projectile) and projectile.team == 2, "real projectile parry reflects and emits splash")
	actor._tide_cancel()
	check(not actor._tide_fx[0].visible and not actor._tide_fx[1].visible, "cancel immediately hides guard")
	actor._guard_blend = 1
	actor._update_tide_fx(0)
	actor._die()
	check(not actor._tide_fx[0].visible and not actor._tide_fx[1].visible, "death immediately hides guard")
	for i in 110:
		CombatVFX.impact(stage, Vector3.ZERO)
	check(get_node_count_in_group("combat_vfx_transient") == CombatVFX.MAX_TRANSIENT, "effect count capped at 96")
	await create_timer(2.0).timeout
	check(get_node_count_in_group("combat_vfx_transient") == 0, "all transient effects reclaimed")
	stage.queue_free()
	await process_frame
	var report := {"passed": not failed, "checks": checks}
	var file := FileAccess.open("E:/godot_game_by_fable/_review/combat_vfx/validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("COMBAT_VFX_VALIDATION ", JSON.stringify(report))
	quit(1 if failed else 0)
