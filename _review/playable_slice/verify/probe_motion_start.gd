extends SceneTree
## Independent probe: why does test_nezha_motion fail "breathing idle selected" at 8 frames?
var actor
var world: Node3D

func _initialize() -> void:
	call_deferred("_run")

func _frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame

func _spawn(script_path: String) -> bool:
	var scr = load(script_path)
	if scr == null:
		print("LOAD_FAIL ", script_path)
		return false
	world = Node3D.new()
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(100, 1, 10)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position.y = -0.5
	world.add_child(floor_body)
	actor = scr.new()
	world.add_child(actor)
	return true

func _probe(tag: String) -> void:
	print("--- ", tag, " ---")
	for i in 12:
		await physics_frame
		await process_frame
		var cur: String = actor._motion.current if actor._motion else "<none>"
		print("f=", i + 1, " current=", cur, " land_left=", actor._motion._land_left if actor._motion else -1.0,
			" on_floor=", actor.is_on_floor(), " y=", snappedf(actor.position.y, 0.001),
			" vy=", snappedf(actor.velocity.y, 0.001), " act=", actor.act)

func _run() -> void:
	if not _spawn("res://scripts/player.gd"):
		quit(2); return
	await _probe("current")
	world.queue_free()
	await process_frame
	if not _spawn("E:/godot_game_by_fable/_review/playable_slice/baseline/files/001/scripts/player.gd"):
		print("BASELINE_LOAD_FAILED")
		quit(0); return
	await _probe("baseline")
	quit(0)
