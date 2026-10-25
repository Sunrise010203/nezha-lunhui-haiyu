extends SceneTree
## 第一章可玩性修复的行为回归（t2）
## 只做"真实状态"断言：不看方法是否存在，而是真的把角色放进水里、
## 真的暂停、真的死一次，再检查血量 / 面板种类 / 状态字段 / 灵力数值。
##
## 运行：
##   Godot_v4.6.3-stable_win64_console.exe --headless --path 001 \
##       --script res://tools/test_gameplay_states.gd

var failures := 0
var checks := 0
## --script 模式下全局标识符 Game 在编译期不可见，运行时从 /root/Game 取
var game: Node

const EnergyRegen := preload("res://scripts/energy_regen.gd")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL ", message)
		push_error("FAIL " + message)
	else:
		print("PASS ", message)


func _initialize() -> void:
	call_deferred("run")


func wait_frames(n: int) -> void:
	for i in n:
		await physics_frame


func wait_process_frames(n: int) -> void:
	for i in n:
		await process_frame


func pause_event() -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = "pause"
	ev.pressed = true
	return ev


func count_visible_hints(level: Node) -> int:
	var n := 0
	for h: Dictionary in level.get("_hints"):
		if float(h["alpha"]) > 0.5:
			n += 1
	return n


func run() -> void:
	print("=== EnergyRegen 纯函数 ===")
	test_energy_regen_math()
	print("=== 关卡内行为 ===")
	await test_level_behaviour()
	print("GAMEPLAY_STATES checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)


func test_energy_regen_math() -> void:
	check(is_equal_approx(EnergyRegen.DELAY, 3.0), "脱战阈值 3 秒")
	check(is_equal_approx(EnergyRegen.rate(100.0), 5.0), "每秒恢复上限的 5%（MAX 100 → 5/s）")
	check(is_equal_approx(EnergyRegen.step(10.0, 100.0, 2.9, 0.016, true, false), 10.0),
		"脱战不足 3 秒不恢复")
	check(is_equal_approx(EnergyRegen.step(10.0, 100.0, 3.0, 0.0, true, false), 10.0),
		"刚跨过阈值且 delta=0 时不发放")
	var e1 := EnergyRegen.step(10.0, 100.0, 3.2, 0.016, true, false)
	check(e1 > 10.0 and e1 < 10.1, "跨阈值那一帧只补超出的小段（实测 %.3f）" % e1)
	var e2 := EnergyRegen.step(10.0, 100.0, 9.0, 1.0, true, false)
	check(is_equal_approx(e2, 15.0), "满脱战时 1 秒回 5 点（实测 %.2f）" % e2)
	check(is_equal_approx(EnergyRegen.step(10.0, 100.0, 9.0, 1.0, true, true), 10.0),
		"暂停不恢复")
	check(is_equal_approx(EnergyRegen.step(10.0, 100.0, 9.0, 1.0, false, false), 10.0),
		"死亡不恢复")
	check(is_equal_approx(EnergyRegen.step(99.9, 100.0, 9.0, 1.0, true, false), 100.0),
		"恢复不超过上限")


func test_level_behaviour() -> void:
	game = root.get_node_or_null("Game")
	check(game != null, "autoload Game 可用")
	if game == null:
		return
	game.start_campaign()
	var level := (load("res://scenes/level_1.tscn") as PackedScene).instantiate()
	root.add_child(level)
	for i in 300:
		await process_frame
		if level.get("build_done"):
			break
	check(level.get("build_done") == true, "关卡构建完成")
	# 注意：这里不能写 `: Player` / `: HUD` 类型标注。--script 模式下脚本在
	# autoload 注册前编译，一旦在编译期依赖 player.gd/hud.gd（它们引用 Game），
	# 整条依赖链会以 "Identifier not found: Game" 失败。
	var player = level.get("player")
	var hud = level.get("hud")
	check(player != null and hud != null, "玩家与 HUD 就绪")
	if player == null or hud == null:
		return
	await wait_frames(20)

	# ---------------------------------------------------------------- 布局未被改动
	check(level.get("_checkpoints").size() == 5, "莲台数量仍是 5（地形/收集坐标未改）")
	var hints: Array = level.get("_hints")
	check(hints.size() == 9, "教学提示仍是 9 条（未新增常驻面板）")

	# ---------------------------------------------------------------- 教学：单条 + 邻近 + 淡出
	player.global_position = Vector3(3.0, 1.2, 0.0)
	player.velocity = Vector3.ZERO
	await wait_frames(30)
	check(count_visible_hints(level) == 1, "靠近教学点时同屏只亮一条提示")
	var first: Dictionary = hints[0]
	check(float(first["alpha"]) > 0.8, "最近的一条已淡入")
	var text_a: String = (first["label"] as Label3D).text
	check("A / D" in text_a, "操作文案与实际键位一致（A/D 移动）")
	player.global_position = Vector3(300.0, 1.2, 0.0)
	await wait_frames(30)
	check(count_visible_hints(level) == 0, "离开教学范围后提示淡出")
	# 已完成（做对动作）的提示永久收起：标记后回到原处也不应再淡入
	for h: Dictionary in hints:
		if h["done_action"] == "jump":
			h["done"] = true
	player.global_position = Vector3(3.0, 1.2, 0.0)
	await wait_frames(30)
	check(float(hints[0]["alpha"]) <= 0.02, "已经做对过的提示不再弹出")
	check(bool(hints[0]["done"]) == true, "该提示保持完成标记")
	for h: Dictionary in hints:
		h["done"] = false

	# ---------------------------------------------------------------- 落水：单次扣血 + 单次击退
	player.global_position = Vector3(4.0, 1.0, 0.0)
	player.velocity = Vector3.ZERO
	player.invuln = 0.0
	await wait_frames(10)
	var hp0: float = player.hp
	var vmax := 0.0
	player.global_position = Vector3(103.0, 5.0, 0.0)   # 水廊正中的水面
	player.velocity = Vector3.ZERO
	for i in 45:
		await physics_frame
		vmax = maxf(vmax, absf(player.velocity.x))
	var lost: float = hp0 - player.hp
	check(is_equal_approx(lost, 4.0), "落水只结算一次 4 点伤害（实际 %.1f）" % lost)
	check(player.get("_external_vel") == Vector3.ZERO,
		"落水不再叠加关卡外力（重复击退已消除）")
	check(vmax > 3.0 and vmax < 11.0, "落水水推只有一次（峰值 vx=%.2f，旧实现会到 14+）" % vmax)

	# ---------------------------------------------------------------- 复活（选关路径）清理临时状态
	player.global_position = Vector3(4.0, 1.0, 0.0)
	player.velocity = Vector3.ZERO
	await wait_frames(10)
	var energy_keep := 12.5
	player.energy = energy_keep
	player._energy_prev = energy_keep
	player.wheel_t = 3.0
	player._wheel_airborne = true
	player._ring_charging = true
	player._ring_charge = 0.5
	player.attack_queued = true
	player.attack_buffer_t = 0.1
	player.jump_buffer = 0.1
	player.combo_cd = 0.2
	player.dash_t = 0.1
	player.dash_cd_t = 0.2
	player._slow_amount = 0.4
	player._slow_t = 2.0
	player.act = "hurt"
	player.act_t = 0.0
	player.respawn(Vector3(4.0, 1.0, 0.0))
	check(player.hp == player.MAX_HP, "复活回满生命")
	check(player.act == "free", "复活回到可控状态")
	check(player.wheel_t == 0.0 and player._wheel_airborne == false,
		"复活清掉风火轮腾空窗口")
	check(player._ring_charging == false and player._ring_charge == 0.0
		and player._ring_out == false, "复活清掉乾坤圈蓄力/在途标记")
	check(player.attack_queued == false and player.attack_buffer_t == 0.0
		and player.jump_buffer == 0.0, "复活清空输入队列与缓冲")
	check(player.dash_t == 0.0 and player.dash_cd_t == 0.0 and player.combo_cd == 0.0,
		"复活清空冲刺/连击冷却")
	check(player._slow_amount == 0.0 and player._slow_t == 0.0, "复活清掉减速")
	check(is_equal_approx(player.energy, energy_keep),
		"复活保留灵力数值，不默认回满（%.1f）" % player.energy)
	# 幂等：再来一次不会改变结论
	player.respawn(Vector3(4.0, 1.0, 0.0))
	check(player.hp == player.MAX_HP and player.act == "free"
		and is_equal_approx(player.energy, energy_keep), "重复复活幂等")

	# ---------------------------------------------------------------- 在途乾坤圈必须被销毁
	player._throw_ring(0.0)
	var ring_node = player.get("_ring_throw")
	check(ring_node != null and is_instance_valid(ring_node), "乾坤圈已掷出（在途）")
	player.respawn(Vector3(4.0, 1.0, 0.0))
	await wait_frames(3)
	check(ring_node == null or not is_instance_valid(ring_node),
		"复活销毁在途乾坤圈实体")
	check(player._ring_out == false, "复活后乾坤圈立即可再掷")

	# ---------------------------------------------------------------- 复活防重复（连续两次回调）
	level._respawn_full()
	level._respawn_full()
	await wait_frames(50)
	check(level.get("_respawning") == false, "复活互斥锁已释放")
	check(player.act == "free" and player.hp == player.MAX_HP, "重复复活回调后状态仍然干净")

	# ---------------------------------------------------------------- 灵力：存活脱战才恢复
	player.global_position = Vector3(4.0, 1.0, 0.0)
	player.velocity = Vector3.ZERO
	await wait_frames(10)
	player.energy = 10.0
	player._energy_prev = 10.0
	player._reset_energy_idle()
	await wait_frames(100)
	check(player.energy <= 10.01, "脱战不足 3 秒不恢复（%.2f）" % player.energy)
	player.energy = 10.0
	player._energy_prev = 10.0
	player.energy_idle = 3.0
	await wait_frames(60)
	var gained: float = player.energy - 10.0
	check(gained > 4.0 and gained < 6.0, "脱战满 3 秒后按 5/s 恢复（1 秒实测 +%.2f）" % gained)
	# 暂停不恢复
	player.energy = 10.0
	player._energy_prev = 10.0
	player.energy_idle = 3.0
	hud._input(pause_event())
	await wait_frames(40)
	check(hud.get("_paused") == true and paused == true, "Esc 打开暂停并冻结场景")
	check(hud.overlay_kind() == "pause", "暂停面板种类为 pause")
	var e_paused: float = player.energy
	check(e_paused <= 10.01, "暂停期间灵力不恢复（%.2f）" % e_paused)
	hud._input(pause_event())
	check(hud.get("_paused") == false and paused == false, "再按 Esc 能恢复游戏（旧计划写法会卡死）")
	check(hud.overlay_kind() == "", "恢复后面板已清除")
	# 死亡不恢复、也不累计脱战
	player.energy = 20.0
	player._energy_prev = 20.0
	player.act = "dead"
	player.energy_idle = 5.0
	await wait_frames(30)
	check(player.energy <= 20.01, "死亡期间灵力不恢复（%.2f）" % player.energy)
	check(player.energy_idle == 0.0, "死亡期间不累计脱战计时")
	player.act = "free"

	# ---------------------------------------------------------------- 蓄力即战斗态（final-review F3）
	# 旧实现：`_start_ring_charge()` 只设 act="charge_ring"，不重置脱战；从"已脱战 3 秒"
	# 起手会边蓄力边按 5/s 回灵。这里把 energy_idle 直接置 3.0 复现那个临界状态。
	player.respawn(Vector3(4.0, 1.0, 0.0))
	player.global_position = Vector3(4.0, 1.0, 0.0)
	await wait_frames(5)
	player.energy = 40.0
	player._energy_prev = 40.0
	player.energy_idle = 3.0
	player._start_ring_charge()
	check(player.act == "charge_ring" and player.energy_idle == 0.0,
		"E 起手蓄力立刻重置脱战计时")
	await wait_frames(30)      # 0.5s
	check(is_equal_approx(player.energy, 40.0),
		"蓄力 0.5 秒不回灵（旧实现 +2.5 → 42.5，实际 %.2f）" % player.energy)
	# 蓄力被打断：立刻失去蓄力态，且不回灵
	player.invuln = 0.0
	player.take_damage(6.0, player.global_position.x + 1.0)
	await wait_frames(30)
	check(player._ring_charging == false, "受击打断蓄力")
	check(is_equal_approx(player.energy, 40.0),
		"蓄力被打断后 0.5 秒内不回灵（%.2f）" % player.energy)
	check(player.energy_idle < 1.0,
		"蓄力被打断后重新数脱战（0.5s 内只累计 %.2fs，远未到 3s）" % player.energy_idle)
	# 蓄力结束回到可控：仍要等满 3 秒
	player.respawn(Vector3(4.0, 1.0, 0.0))
	player.global_position = Vector3(4.0, 1.0, 0.0)
	player.energy = 40.0
	player._energy_prev = 40.0
	player._start_ring_charge()
	await wait_frames(5)
	player._ring_charging = false      # 等价于松手结束蓄力
	player.act = "free"
	player.act_t = 0.0
	await wait_frames(100)             # 1.6s < 3s
	check(is_equal_approx(player.energy, 40.0),
		"蓄力结束后 1.6 秒内仍不回灵（%.2f）" % player.energy)
	player.energy_idle = 3.0
	await wait_frames(60)
	var after_charge: float = player.energy - 40.0
	check(after_charge > 4.0 and after_charge < 6.0,
		"蓄力结束满 3 秒后按既定 5/s 恢复（1 秒实测 +%.2f）" % after_charge)
	# 真实输入路径：按住 E → 蓄力；松手 → 扣 25 并从零开始计时
	game.skills["E"] = true            # 首章默认锁 E，这里只验证机制，随后还原
	player.respawn(Vector3(4.0, 1.0, 0.0))
	player.global_position = Vector3(4.0, 1.0, 0.0)
	player.energy = 40.0
	player._energy_prev = 40.0
	await wait_frames(3)
	Input.action_press("skill2")
	await physics_frame
	await physics_frame
	check(player.act == "charge_ring", "按住 E 进入蓄力（真实输入路径）")
	Input.action_release("skill2")
	await physics_frame
	await physics_frame
	check(is_equal_approx(player.energy, 15.0),
		"松手扣 25 灵力（40 → %.1f）" % player.energy)
	check(player.energy_idle == 0.0, "松手后脱战计时从零开始")
	game.skills["E"] = false           # 还原首章解锁状态
	# 普通出招期间同样不回灵
	player.respawn(Vector3(4.0, 1.0, 0.0))
	player.global_position = Vector3(4.0, 1.0, 0.0)
	player.energy = 40.0
	player._energy_prev = 40.0
	player.energy_idle = 3.0
	player.combo_cd = 0.0
	player._start_action("atk1")
	await wait_frames(15)              # atk1 全程（约 0.3s）
	check(is_equal_approx(player.energy, 40.0),
		"出招期间不回灵（%.2f）" % player.energy)
	# 蓄力态下暂停 / 死亡都不回灵
	player.respawn(Vector3(4.0, 1.0, 0.0))
	player.global_position = Vector3(4.0, 1.0, 0.0)
	player.energy = 40.0
	player._energy_prev = 40.0
	player._start_ring_charge()
	player.energy_idle = 3.0
	hud._input(pause_event())
	await wait_frames(30)
	check(hud.overlay_kind() == "pause" and is_equal_approx(player.energy, 40.0),
		"蓄力中暂停不回灵（%.2f）" % player.energy)
	hud._input(pause_event())
	await wait_frames(3)
	player.energy = 40.0
	player._energy_prev = 40.0
	player._start_ring_charge()
	player.energy_idle = 3.0
	player.act = "dead"                # 死亡瞬间
	await wait_frames(20)
	check(is_equal_approx(player.energy, 40.0) and player.energy_idle == 0.0,
		"蓄力中死亡不回灵且不累计脱战（%.2f）" % player.energy)
	player.act = "free"
	player._ring_charging = false

	# ---------------------------------------------------------------- 输入缓冲：一次按键只补一招
	player.respawn(Vector3(4.0, 1.0, 0.0))
	player.global_position = Vector3(4.0, 1.0, 0.0)
	await wait_frames(5)
	player.combo_cd = 0.0
	player.act = "hurt"
	player.act_t = 0.0
	Input.action_press("attack")
	await physics_frame
	await physics_frame
	Input.action_release("attack")
	check(player.attack_buffer_t > 0.0 and player.attack_buffer_t <= 0.12,
		"硬直中按攻击会被记入 0.12s 缓冲（%.3f）" % player.attack_buffer_t)
	check(player.act == "hurt", "缓冲期间不会强行出招（不突破硬直）")
	player.act = "free"
	player.act_t = 0.0
	await physics_frame
	await physics_frame
	check(player.act.begins_with("atk"), "恢复可控后缓冲只补一次普通攻击（act=%s）" % player.act)
	check(player.attack_buffer_t == 0.0, "缓冲已被消费，不会重复触发")
	# 缓冲过期后不再补
	player.respawn(Vector3(4.0, 1.0, 0.0))
	player.global_position = Vector3(4.0, 1.0, 0.0)
	await wait_frames(5)
	player.act = "hurt"
	player.act_t = 0.0
	Input.action_press("attack")
	await physics_frame
	await physics_frame
	Input.action_release("attack")
	await wait_frames(12)     # ~0.2s > 0.12s
	check(player.attack_buffer_t == 0.0, "超过 0.12 秒的缓冲自动过期")
	player.act = "free"
	player.act_t = 0.0
	await physics_frame
	await physics_frame
	check(not player.act.begins_with("atk"), "过期缓冲不会在恢复后补招")

	# ---------------------------------------------------------------- 死亡：闯关整章重来 + 面板互斥
	player.respawn(Vector3(4.0, 1.0, 0.0))
	player.global_position = Vector3(4.0, 1.0, 0.0)
	await wait_frames(10)
	check(game.campaign == true and game.campaign_chapter == "ch1",
		"测试处于闯关模式（ch1）")
	player.invuln = 0.0
	player.hp = 5.0
	player.take_damage(20.0, 0.0)
	check(player.is_dead(), "致死伤害后玩家进入死亡状态")
	# 死亡等待面板期间（1.1s）Esc 不得暂停
	hud._input(pause_event())
	check(paused == false and hud.get("_paused") == false,
		"死亡结算等待期间 Esc 不会打开暂停菜单")
	# 死亡面板要等 1.1 秒的真实计时器：按真实时间轮询，而不是按帧数
	var t0 := Time.get_ticks_msec()
	while hud.overlay_kind() != "campaign_death" and Time.get_ticks_msec() - t0 < 4000:
		await process_frame
	check(hud.overlay_kind() == "campaign_death",
		"闯关模式死亡弹出整章重开面板（不是莲台复活）")
	check(level.get("_death_pending") == true, "关卡标记了待处理死亡")
	# 死亡面板打开时 Esc 不得再叠一层
	var overlay_ref = hud.get("_overlay")
	hud._input(pause_event())
	check(hud.overlay_kind() == "campaign_death", "死亡面板打开时 Esc 不会改成暂停面板")
	check(hud.get("_overlay") == overlay_ref, "死亡面板没有被清掉重建")
	hud.show_campaign_death("第一章 · 东海 碎潮回廊")
	await wait_process_frames(3)
	check(hud.get("_overlay") == overlay_ref, "重复死亡回调不会叠第二个面板")
	check(paused == false, "死亡面板期间场景不处于暂停")

	hud._clear_overlay()
	hud.queue_free()
	level.queue_free()
	await wait_process_frames(8)
