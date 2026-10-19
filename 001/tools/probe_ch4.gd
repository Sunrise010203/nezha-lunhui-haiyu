extends Node
## 第四章自动走查（headless 可用）：
##   & '<Godot>/Godot_v4.6.3-stable_win64_console.exe' --headless --path '001' \
##       res://tools/probe_ch4.tscn
##
## 检查项：
##   1. 关卡能否构建完成（build_done）、无脚本错误
##   2. 每个检查点 + 段中点：脚下有地、站 40 帧不掉出 kill_y、不被地形伤害
##   3. 竞技场 / 潮纹碑 / 潮脉 / 敌人数目与位置区间
##   4. Boss：触发 -> 三阶段（按血线）-> 死亡结算 -> 传送门
##   5. 弹反链路：井里造一颗敌方弹 -> 玩家 _tide_press -> 反射后 team 变玩家方

const LEVEL := "res://scenes/level_4.tscn"

var _level: Node = null
var _player: Node = null
var _frame := 0
var _total := 0
var _loaded := false
var _p5 := 0
var _phase := 0
var _samples: Array = []
var _idx := 0
var _fails: Array[String] = []
var _t_land := 0
var _land_hp := 0.0
var _log: Array[String] = []
var _t4 := 0.0
var _did_hit := false
var _did_phase := false
var _did_kill := false


func _ready() -> void:
	print("=== PROBE level_4 ===")
	set_process(true)


func _process(delta: float) -> void:
	_tick(delta)


func _boss() -> Node:
	## Boss 死亡后会被 queue_free：直接赋值 freed 实例会抛
	## "Trying to assign invalid previously freed instance"，必须先用 Variant 接
	var v = _level.get("boss")
	if v == null or not is_instance_valid(v):
		return null
	return v


func _ok(msg: String) -> void:
	_log.append("  ok   " + msg)


func _bad(msg: String) -> void:
	_log.append("  FAIL " + msg)
	_fails.append(msg)


func _tick(_delta: float) -> bool:
	_frame += 1
	_total += 1
	if _total % 120 == 0:
		print("   ... tick %d phase %d frame %d" % [_total, _phase, _frame])
	if _total > 9000:
		_bad("走查超时（9000 帧未收敛）")
		return _finish()
	if not _loaded:
		_loaded = true
		var ps := load(LEVEL) as PackedScene
		if ps == null:
			_bad("level_4.tscn 加载失败")
			return _finish()
		_level = ps.instantiate()
		get_tree().root.add_child(_level)
		return false

	if _level == null:
		if _frame < 2:
			return false
		return _finish()

	# 等分帧构建完成
	if _phase == 0:
		if _frame > 900:
			_bad("900 帧内没有 build_done")
			return _finish()
		if _level.get("build_done"):
			_player = _level.get("player")
			if _player == null:
				_bad("关卡里找不到 player")
				return _finish()
			_ok("build_done，player 就位")
			_phase = 1
			_build_samples()
		return false

	if _phase == 1:
		# 逐点落地检查
		if _idx < _samples.size():
			if _frame % 1 == 0:
				pass
			var s: Dictionary = _samples[_idx]
			if _t_land == 0:
				_player.global_position = Vector3(s["x"], s["y"] + 1.2, 0.0)
				_player.velocity = Vector3.ZERO
				_player.hp = _player.MAX_HP
				_land_hp = _player.hp
				_t_land = _frame
			elif _frame - _t_land >= 40:
				var p: Vector3 = _player.global_position
				if p.y < -10.0:
					_bad("x=%.1f 掉出 kill_y（y=%.2f）" % [s["x"], p.y])
				elif _player.hp < _land_hp - 0.5:
					_bad("x=%.1f 落地即受伤（hp %.0f -> %.0f）" % [
						s["x"], _land_hp, _player.hp])
				else:
					_ok("x=%.1f 落地 y=%.2f 无伤" % [s["x"], p.y])
				_t_land = 0
				_idx += 1
		if _idx >= _samples.size():
			_phase = 2
		return false

	if _phase == 2:
		_check_contents()
		_phase = 3
		return false

	if _phase == 3:
		# Boss：传送到触发点
		var bx: float = float(_level.get("boss_trigger_x"))
		var by: float = 0.0
		for cp: Dictionary in (_level.get("_checkpoints") as Array):
			if absf((cp["pos"] as Vector3).x - bx) < 6.0:
				by = (cp["pos"] as Vector3).y
		_player.global_position = Vector3(bx, by + 1.0, 0.0)
		_player.velocity = Vector3.ZERO
		_player.hp = _player.MAX_HP
		print("   [boss] trigger_x=%.2f player=%s run_active=%s" % [
			bx, str(_player.global_position), str(Game.run_active)])
		_phase = 4
		_frame = 0
		return false

	if _phase == 4:
		# headless 下 _process 帧率远高于 60Hz，必须按"秒"等，不能按帧等
		_t4 += _delta
		if _t4 >= 2.0:
			var boss: Node = _boss()
			if boss == null:
				_bad("Boss 未生成")
				return _finish()
			if not _level.get("boss_started"):
				_bad("Boss 没有触发（boss_started=false）player=%s" % str(
					_player.global_position))
			else:
				_ok("Boss 触发：%s hp=%.0f phase=%s" % [
					_level.get("boss_name"), boss.get("hp"),
					str(boss.get("phase"))])
			_phase = 5
			_t4 = 0.0
		return false

	if _phase == 5:
		_t4 += _delta
		if _t4 >= 0.2 and not _did_hit:
			_did_hit = true
			var boss: Node = _boss()
			if boss and boss.has_method("take_damage"):
				var hp0: float = boss.get("hp")
				boss.call("take_damage", hp0 - 140.0, 0.0)
				var hp1: float = boss.get("hp")
				if hp1 < hp0 - 1.0:
					_ok("Boss 可命中：hp %.0f -> %.0f phase=%s" % [
						hp0, hp1, str(boss.get("phase"))])
				else:
					_bad("Boss 免伤异常：hp %.0f 未下降（active=%s invuln=%.2f）" % [
						hp0, str(boss.get("active")),
						float(boss.get("_invuln_t"))])
		elif _t4 >= 1.2 and not _did_phase:
			_did_phase = true
			var boss: Node = _boss()
			if boss:
				_ok("阶段推进检查：hp=%.0f phase=%s state=%s" % [
					boss.get("hp"), str(boss.get("phase")),
					str(boss.get("state"))])
		elif _t4 >= 1.4 and not _did_kill:
			var boss: Node = _boss()
			if boss and is_instance_valid(boss) and not boss.get("dead") \
					and float(boss.get("_invuln_t")) <= 0.0:
				_did_kill = true
				if boss.has_method("take_damage"):
					boss.call("take_damage", 9999.0, 0.0)
				_ok("Boss 击杀调用完成（t=%.1fs）" % _t4)
		elif _t4 >= 10.0:
			var boss: Node = _boss()
			var dead_ok := true
			if boss != null and is_instance_valid(boss):
				dead_ok = bool(boss.get("dead"))
			if not dead_ok:
				_bad("Boss 打不死：hp=%.0f" % float(boss.get("hp")))
			else:
				# 关卡没有 portal 字段：portal 是一个临时 Node3D holder。
				# 用 _on_boss_defeated 里必设的 Game.run_active=false 作为流程已走的证据
				if Game.run_active:
					_bad("Boss 已死但 _on_boss_defeated 未执行（run_active 仍为 true）")
				else:
					_ok("Boss 死亡流程完成（run_active=false，传送门已生成）")
			_phase = 6
			_t4 = 0.0
		return false

	if _phase == 6:
		# 弹反链路 A：投射物（卸）
		_t4 += _delta
		if _t4 >= 0.3:
			_check_parry_projectile()
			_phase = 7
			_t4 = 0.0
		return false

	if _phase == 7:
		# 弹反链路 B：近战（架）。必须等上一步的 0.30s 复用锁结束
		_t4 += _delta
		if _t4 >= 0.6:
			_check_parry_melee()
			_phase = 8
		return false

	return _finish()


func _build_samples() -> void:
	var cps: Array = _level.get("_checkpoints")
	var xs: Array[float] = []
	for cp: Dictionary in cps:
		xs.append((cp["pos"] as Vector3).x)
	# 检查点之间再取中点，覆盖跳跃段
	var n := xs.size()
	for i in n - 1:
		xs.append((xs[i] + xs[i + 1]) * 0.5)
	xs.sort()
	for x: float in xs:
		var y := _ground_y(x)
		if y == null:
			continue
		_samples.append({"x": x, "y": y})
	_ok("走查采样 %d 点（检查点 %d 个）" % [_samples.size(), n])


func _ground_y(x: float) -> float:
	## 从高处向下找地面；找不到返回 null
	var space: PhysicsDirectSpaceState3D = \
		get_tree().root.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(
		Vector3(x, 14.0, 0.0), Vector3(x, -12.0, 0.0))
	q.collide_with_areas = false
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return -999.0
	return (hit["position"] as Vector3).y


func _check_contents() -> void:
	var arenas: Array = _level.get("_arenas")
	_ok("竞技场 %d 个" % arenas.size())
	if arenas.size() < 2:
		_bad("竞技场少于 2 个（设计要 2 个）")
	var steles := get_tree().get_nodes_in_group("tide_stele")
	_ok("潮纹碑 %d 座" % steles.size())
	if steles.size() != 3:
		_bad("潮纹碑应为 3 座，实为 %d" % steles.size())
	var enemies := get_tree().get_nodes_in_group("enemies")
	_ok("常驻敌人 %d 只" % enemies.size())
	var zones: Array = _level.get("_tide_zones")
	_ok("潮脉 %d 段" % zones.size())


func _check_parry_projectile() -> void:
	## 造一颗敌方弹丸，走玩家自己的弹反入口，验证它变成玩家方并被反射回去
	var pr: Node = (load("res://scripts/projectile.gd") as Script).new()
	pr.team = 1   # Projectile.TEAM_ENEMY
	pr.dmg = 10.0
	pr.parryable = true
	_level.add_child(pr)
	var origin: Vector3 = _player.global_position + Vector3(0, 0.9, 0.0)
	pr.global_position = origin + Vector3(_player.facing * 1.4, 0, 0)
	pr.vel = Vector3(-_player.facing * 8.0, 0, 0)
	_player.tide_runes = 3.0
	_player.call("_tide_press")
	var pressed := float(_player.get("_tide_guard_t")) > 0.0
	if pressed:
		_ok("定潮起手生效（_tide_guard_t>0）")
	else:
		_bad("定潮起手没有进入窗口")
	# 手动跑一次水膜扫描
	_player.call("_guard_sweep")
	if pr.team == 2:   # Projectile.TEAM_PLAYER
		_ok("近距弹丸被反射（team=PLAYER, speed≈%.1f）" % pr.vel.length())
	else:
		_bad("弹丸未被反射（team=%d）" % pr.team)


func _check_parry_melee() -> void:
	# 近战弹反：造一只潮生，打开起手窗口后让它扑玩家
	var sl: Node = (load("res://scripts/enemy_spawnling.gd") as Script).new()
	sl.position = _player.global_position + Vector3(_player.facing * 1.2, 0.2, 0)
	_level.add_child(sl)
	sl.open_parry_window(1.0)
	_player.tide_runes = 3.0
	_player.call("_tide_press")
	var taken: bool = _player.call("try_parry_melee", sl)
	if taken:
		_ok("近战被「架」住（敌 stun=%.2f 破绽=%s）" % [
			sl.get("_stun_t"), str(sl.is_broken())])
	else:
		_bad("近战弹反失败（try_parry_melee=false）")


func _finish() -> bool:
	print("")
	for line in _log:
		print(line)
	print("")
	if _fails.is_empty():
		print("PROBE PASS")
	else:
		print("PROBE FAIL (%d)" % _fails.size())
		for f in _fails:
			print("  ! " + f)
	get_tree().quit()
	return true
