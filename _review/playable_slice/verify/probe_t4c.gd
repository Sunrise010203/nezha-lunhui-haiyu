extends SceneTree

func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/level_1.tscn")
	var level = scene.instantiate()
	root.add_child(level)
	for i in 4:
		await process_frame
	var p = level.get("player")
	print("PLAYER=", p)
	# 1) skill press during hurt must not enter attack buffer nor cast
	p.hp = 100.0
	p.energy = 10.0
	p.energy_idle = 3.5
	p.act = "hurt"
	p.act_t = 0.0
	p.combo_cd = 0.0
	p.set("wheel_t", 0.0)
	Input.action_press("skill2")
	await physics_frame
	await physics_frame
	Input.action_release("skill2")
	print("SKILL_IN_HURT buffer=%.3f act=%s wheel_t=%.3f" % [p.attack_buffer_t, p.act, p.get("wheel_t")])
	# 2) after recovery, no queued skill/wheel
	p.act = "free"
	p.act_t = 0.0
	for i in 3:
		await physics_frame
	print("SKILL_AFTER_RECOVER act=%s wheel_t=%.3f buffer=%.3f" % [p.act, p.get("wheel_t"), p.attack_buffer_t])
	# 3) empty swing (attack in free) resets out-of-combat idle
	p.energy = 10.0
	p.energy_idle = 3.5
	p.combo_cd = 0.0
	p.act = "free"
	p.act_t = 0.0
	Input.action_press("attack")
	await physics_frame
	await physics_frame
	Input.action_release("attack")
	print("EMPTY_SWING act=%s idle=%.3f" % [p.act, p.energy_idle])
	quit()
