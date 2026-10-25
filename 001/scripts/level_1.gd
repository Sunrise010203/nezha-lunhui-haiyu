extends LevelBase
## 第一章 · 东海 碎潮回廊
## 内容：教学段 → 封印竞技场 → 上升浮台 → 碎裂浮桥 → 试炼长廊 → Boss「归墟之喉」
## 地形/装饰/遭遇战全部用 LevelBase 的积木拼装；本文件只放本章的编排。

const LEN := 164.0


func _configure() -> void:
	chapter_title = "第一章 · 东海 碎潮回廊"
	chapter_id = "ch1"
	next_scene = ""                      # 每关独立：通关只结算本章，不自动进第二章
	soul_goal = 3
	spawn_wildlife = false
	water_caustics = false
	boss_name = "归墟之喉 · 渊狱兽"
	boss_defeat_msg = "渊 兽 已 被 镇 压"
	portal_msg = "碎潮回廊秩序已恢复 · 龙魂归位"
	zone_stops = [
		[0.0, Color(0.05, 0.16, 0.2), Color(0.25, 0.4, 0.45),
			Color(0.3, 0.6, 0.65)],
		[75.0, Color(0.045, 0.115, 0.225), Color(0.23, 0.33, 0.5),
			Color(0.3, 0.45, 0.7)],
		[112.0, Color(0.08, 0.07, 0.2), Color(0.33, 0.25, 0.46),
			Color(0.45, 0.3, 0.68)],
		[150.0, Color(0.09, 0.04, 0.11), Color(0.3, 0.17, 0.26),
			Color(0.5, 0.22, 0.36)],
	]


# ================================================================ 地形 + 装饰

func _build_layout() -> void:
	_build_terrain()
	await get_tree().process_frame
	await _build_decor()
	await get_tree().process_frame
	_build_decor_props()


func _build_terrain() -> void:
	# A 起点台地
	_platform(-8, 16, 0)
	_add_checkpoint(Vector3(-4, 0, 0), true)   # 莲台挪到身后，出生时不再站在花瓣里
	_hint("A / D 移动　·　空格 跳跃（空中再按一次二段跳）",
		Vector3(3, 2.2, 0), 7.5, "jump")
	_hint("Shift 冲刺 —— 冲刺中可完美闪身，不受伤", Vector3(13.5, 2.4, 0),
		7.5, "dash")
	_hint("集满 3 枚龙魂残片可解锁新技能（闯关模式）", Vector3(8.5, 2.8, 0))
	# 高处龙魂残片 1（二段跳可达）
	_float_platform(10, 4.4, 2.2)
	_add_pickup(Vector3(10, 5.5, 0), Pickup.Kind.SOUL)
	# B
	_platform(19.5, 30, 0.5)
	_hint("J 连击　·　K 重击　·　空中按 K 下砸", Vector3(22, 2.8, 0),
		7.5, "attack")
	_hint("E 乾坤圈：点按掷出 · 按住蓄力（耗 25 灵力）", Vector3(28, 3.0, 0),
		7.5, "skill2")
	_float_platform(33, 1.8, 2.6)
	# C 封印竞技场
	_platform(36.5, 53, 1)
	_hint("斩除异化之物，封印自解", Vector3(40, 3.6, 0))
	# D 上升浮台
	_float_platform(56, 2.8, 3.0)
	_float_platform(60, 4.2, 3.0)
	_float_platform(64, 5.6, 3.2)
	# E 高台
	_platform(66.5, 86, 6)
	_spikes(78.5, 81.5, 6)
	_add_checkpoint(Vector3(69, 6, 0), false)
	# 竞技场出口莲台：必须落在台面上，且避开 x=52.5 的封印门。
	# 原先把 x 放在 54.5（台面 36.5~53 之外），莲台悬在断崖上方，复活后会直接坠渊。
	_add_checkpoint(Vector3(50.0, 1, 0), false)
	# 浮桥入口莲台：86 是台面右缘，87 已在空隙上方，改到台面内
	_add_checkpoint(Vector3(85.0, 6, 0), false)
	_add_pickup(Vector3(74, 7.0, 0), Pickup.Kind.HEAL)
	# 碎裂浮桥
	for i in 4:
		var fp := FallingPlatform.new()
		fp.width = 2.4
		fp.position = Vector3(88.5 + i * 3.1, 5.75, 0)
		add_child(fp)
	_hint("浮桥已被归墟侵蚀……勿要停留", Vector3(87, 8.2, 0))
	_add_pickup(Vector3(94.5, 8.6, 0), Pickup.Kind.SOUL)
	# F 断桥水廊（100.5~122）：三孔石桥，桥面之间断开 1.5m，桥下是一池浅水。
	# 这是第一章的"专属剖面"——前三章都是长条平地，这里改成"桥面—水—桥面"。
	_platform(100.5, 106.5, 6.0)
	_platform(108.0, 113.0, 6.0)
	_platform(114.5, 119.0, 6.0)
	_platform(120.5, 122.0, 6.0)
	# 桥下池底（落水不致死：扣 6 血 + 被水推回最近的桥头）
	_platform(100.5, 122.0, 4.8, 1.6)
	_pool_water(100.5, 122.0, 5.25)
	_pool_hazard(100.5, 122.0, 4.9)
	for span in [[100.5, 106.5], [108.0, 113.0], [114.5, 119.0], [120.5, 122.0]]:
		_bridge_deck(span[0], span[1])
	_add_pickup(Vector3(111.0, 7.1, 0), Pickup.Kind.ENERGY)
	_add_pickup(Vector3(112.2, 7.3, 0), Pickup.Kind.ENERGY)
	_hint("桥面断开 · 落水扣 4 点生命并被冲回桥头", Vector3(104, 8.6, 0))
	# 下行阶梯
	_float_platform(124.5, 4.6, 2.8)
	_float_platform(127.5, 3.2, 2.8)
	# G Boss 竞技场
	_platform(130, 164, 2)
	_add_checkpoint(Vector3(128.0, 3.2, 0), false, true)
	_hint("前方灵气紊乱……深渊在注视你", Vector3(133, 4.8, 0))
	_add_pickup(Vector3(161.5, 3.2, 0), Pickup.Kind.HEAL)
	_add_pickup(Vector3(162.0, 6.4, 0), Pickup.Kind.SOUL)
	_invisible_wall(164.3, 2.0, 12.0)
	_invisible_wall(-8.3, 0.0, 12.0)


var _bridge_mat: StandardMaterial3D


func _bridge_deck(x0: float, x1: float) -> void:
	## 石桥的桥墩 + 栏杆 + 桥面压边（纯视觉，无碰撞；桥面本体由 _platform 给）
	if _bridge_mat == null:
		_bridge_mat = Game.std_mat(Color(0.26, 0.29, 0.31), Color(0.02, 0.05, 0.06),
			0.04, 0.9)
	var pier := BoxMesh.new()
	pier.size = Vector3(0.55, 2.3, 3.4)
	for px in [x0 + 0.4, x1 - 0.4]:
		Game.add_mesh(self, pier, _bridge_mat, Vector3(px, 4.95, 0.0))
	# 桥面压边：让断口边缘有厚度，读得出"这里断了"
	var lip := BoxMesh.new()
	lip.size = Vector3(x1 - x0, 0.22, 3.5)
	Game.add_mesh(self, lip, _bridge_mat, Vector3((x0 + x1) * 0.5, 6.06, 0.0))
	# 两侧栏杆（细，不挡视线）
	var rail := BoxMesh.new()
	rail.size = Vector3(x1 - x0 - 0.4, 0.10, 0.10)
	for rz in [-1.55, 1.55]:
		Game.add_mesh(self, rail, _bridge_mat,
			Vector3((x0 + x1) * 0.5, 6.85, rz))
		var post := BoxMesh.new()
		post.size = Vector3(0.10, 0.78, 0.10)
		for i in 3:
			var px2 := lerpf(x0 + 0.5, x1 - 0.5, float(i) / 2.0)
			Game.add_mesh(self, post, _bridge_mat, Vector3(px2, 6.45, rz))


func _pool_water(x0: float, x1: float, y: float) -> void:
	## 桥下浅水（纯视觉）：半透明青蓝平面 + 一条水面高光
	var plane := PlaneMesh.new()
	plane.size = Vector2(x1 - x0, 26.0)
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/ch1_water.gdshader")
	var mi := Game.add_mesh(self, plane, m, Vector3((x0 + x1) * 0.5, y, 0.0))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _pool_hazard(x0: float, x1: float, y: float) -> void:
	## 落水惩罚：扣 4 血 + 朝最近的桥头推出去，再把玩家弹回桥面高度。
	## 不用即死，避免"跳桥失误 = 重跑"的挫败感；但也不能白嫖，所以有扣血与 CD。
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2            # 只关心玩家层
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(x1 - x0, 2.0, 4.0)
	cs.shape = box
	area.add_child(cs)
	area.position = Vector3((x0 + x1) * 0.5, y, 0.0)
	area.set_meta("cool", 0.0)
	area.set_meta("x0", x0)
	area.set_meta("x1", x1)
	area.body_entered.connect(_on_pool_entered.bind(area))
	add_child(area)


func _on_pool_entered(body: Node3D, area: Area3D) -> void:
	if not (body is Player):
		return
	var p: Player = body
	# 修复：原来读的是并不存在的 body.dead，每帧脚本报错，落水惩罚从未生效
	if p.is_dead():
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(area.get_meta("cool")) < 2.0:
		return
	area.set_meta("cool", now)
	var x0: float = area.get_meta("x0")
	var x1: float = area.get_meta("x1")
	# 推向更近的一侧桥头，再给一个向上的"被水冲起来"的速度
	var dir := -1.0 if p.global_position.x < (x0 + x1) * 0.5 else 1.0
	var hp_before := p.hp
	p.take_damage(4, p.global_position.x - dir)
	if p.hp < hp_before:
		# 只有伤害真的结算了才给这一次水推。
		# 原来的 apply_external_force + take_damage 的击退会叠加成两倍位移。
		p.velocity = Vector3(dir * 7.5, 10.5, 0.0)
		Game.play_sfx("tide", -6.0, 1.2)
		Game.shake(0.12)


func _build_decor() -> void:
	var ruins := _get_ruins()
	ruins.build_depth()
	ruins.tune_environment(self)
	if cam != null:
		cam.fov = 44.0


func _build_decor_props() -> void:
	# 渊晶瓮（可击碎）
	var urns: Array = [
		[12.0, 0.0, false], [24.5, 0.5, false], [42.0, 1.0, false],
		[50.5, 1.0, true], [71.5, 6.0, false], [85.0, 6.0, false],
		[103.5, 6.0, false], [118.5, 6.0, true], [140.0, 2.0, false],
		[160.0, 2.0, false],
	]
	# 旧陶罐已停用：等待换成新模块化可破坏物
	for u: Array in []:
		var b := Breakable.new()
		b.drop_heal = u[2]
		b.position = Vector3(u[0], u[1], 0.8)
		add_child(b)


# ================================================================ 敌人 / Boss

func _build_encounters() -> void:
	_spawn_crawler(25, 1.0, 20.5, 29.0)
	# 分潮：会分裂的地面怪（第一关专属阵容：爬行者 / 浮母 / 分潮）
	_spawn_divider(22.0, 0.5, 20.0, 29.5)
	await get_tree().process_frame
	# C 封印竞技场：清怪开门
	_lock_arena(52.5, 1.0, 40.0, [
		func() -> EnemyBase: return _spawn_crawler(44, 2.0, 38.0, 51.5),
		func() -> EnemyBase: return _spawn_crawler(48, 2.0, 38.0, 51.5),
		func() -> EnemyBase: return _spawn_shooter(46, 4.2, 39.0, 51.0),
	])
	await get_tree().process_frame
	# D 段悬浮射手
	_spawn_shooter(61, 6.4, 56.0, 65.0)
	await get_tree().process_frame
	# E 段
	_spawn_crawler(76, 7.0, 71.0, 77.5)
	_spawn_crawler(83, 7.0, 82.0, 85.5)
	await get_tree().process_frame
	# F 试炼长廊
	_spawn_crawler(106, 7.0, 101.5, 112.0)
	_spawn_shooter(110, 8.6, 103.0, 118.0)
	_spawn_crawler(115, 7.0, 109.0, 120.5)
	_spawn_shooter(117, 8.2, 110.0, 120.5)
	_spawn_divider(112.0, 6.8, 108.0, 118.0)
	await get_tree().process_frame
	# G Boss
	var b := BossMaw.new()
	b.position = Vector3(150, 5.0, 0)   # 原 6.2：站地近战完全打不到，见评审 P0-1
	add_child(b)
	_setup_boss(b, "归墟之喉 · 渊狱兽", 131.5, 163.0, 2.0, 132.5, 137.0)


# ================================================================ 近中景实体遗迹 / 远景绘景

const RUINS_SCRIPT := preload("res://scripts/ch1_ruins.gd")
var _ruins: Node3D


func _get_ruins() -> Node3D:
	if _ruins == null:
		_ruins = Node3D.new()
		_ruins.set_script(RUINS_SCRIPT)
		_ruins.name = "HybridRuins"
		add_child(_ruins)
	return _ruins


func _platform(x0: float, x1: float, ytop: float, deep := 1.6,
		dark := false) -> StaticBody3D:
	var body := super._platform(x0, x1, ytop, deep, dark)
	_get_ruins().dress_platform(body, x0, x1, ytop, deep)
	return body


func _float_platform(x: float, ytop: float, w := 3.0) -> StaticBody3D:
	var body := super._float_platform(x, ytop, w)
	_get_ruins().dress_platform(body, x - w * 0.5, x + w * 0.5, ytop, 0.8, true)
	return body


func _build_water() -> void:
	super._build_water()
	var sea := get_child(get_child_count() - 1) as MeshInstance3D
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/ch1_water.gdshader")
	sea.material_override = m
