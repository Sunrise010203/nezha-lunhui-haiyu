extends Node
## 验证「乾坤圈一趟只结算一次」：把 Boss 打到可命中状态后，从侧面扔一个圈，
## 记录 hp 变化次数与总伤害。修复前一趟会同时命中躯干+头+逆鳞（2~3 次、翻倍）。

var _done := false


func _ready() -> void:
	# 保底退出：任何脚本错误都不该把 headless 挂死
	get_tree().create_timer(12.0).timeout.connect(func() -> void:
		printerr("RING PROBE TIMEOUT")
		get_tree().quit(2))


func _process(_d: float) -> void:
	if _done:
		return
	_done = true
	_run()


func _run() -> void:
	var lvl = load("res://scenes/level_4.tscn").instantiate()
	get_tree().root.add_child(lvl)
	await get_tree().create_timer(1.5).timeout
	var p: Node = get_tree().get_first_node_in_group("player")
	if p == null:
		printerr("RING PROBE: no player")
		get_tree().quit(2)
		return
	p.set("global_position", Vector3(157.0, 0.2, 0.0))
	await get_tree().physics_frame
	await get_tree().physics_frame
	lvl.call("_start_boss")
	await get_tree().create_timer(2.0).timeout
	var boss = lvl.get("boss")
	if boss == null:
		printerr("RING PROBE: no boss")
		get_tree().quit(2)
		return
	print("probe: hp0=", boss.get("hp"), " active=", boss.get("active"))

	var ring = load("res://scripts/ring_throw.gd").new()
	ring.set("owner_player", p)
	ring.set("dir", 1.0)
	ring.set("dmg", 16.0)
	ring.set("max_dist", 20.0)
	ring.set("global_position", Vector3(155.0, 2.6, 0.0))
	lvl.add_child(ring)

	var hp0: float = float(boss.get("hp"))
	var ticks := 0
	var last := hp0
	for i in 120:
		await get_tree().physics_frame
		var hp: float = float(boss.get("hp"))
		if hp != last:
			ticks += 1
			print("probe: 第 %d 次掉血 %.1f -> %.1f（Δ%.1f）" %
				[ticks, last, hp, last - hp])
			last = hp
		if not is_instance_valid(ring):
			break
	print("probe: 一趟乾坤圈总伤害=", hp0 - float(boss.get("hp")),
		" 掉血事件=", ticks)
	print("RING PROBE DONE")
	get_tree().quit()
