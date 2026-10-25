extends LevelBase
## 第一章 · 东海 碎潮回廊
## 内容：教学段 → 封印竞技场 → 上升浮台 → 碎裂浮桥 → 试炼长廊 → Boss「归墟之喉」
## 地形/装饰/遭遇战全部用 LevelBase 的积木拼装；本文件只放本章的编排。

const LEN := 164.0


func _configure() -> void:
	spawn_wildlife = false  # 旧巨鲸/鱼群剪影与新环境冲突，先关掉
	chapter_title = "第一章 · 东海 碎潮回廊"
	chapter_id = "ch1"
	next_scene = ""                      # 每关独立：通关只结算本章，不自动进第二章
	soul_goal = 3
	spawn_wildlife = true
	water_caustics = true
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
	_hint("A / D 移动　·　空格 跳跃（二段跳）", Vector3(3, 2.2, 0))
	_hint("Shift 冲刺 —— 瞬身无敌", Vector3(13.5, 2.4, 0))
	_hint("集满 3 枚龙魂残片可解锁新技能（闯关模式）", Vector3(8.5, 2.8, 0))
	# 高处龙魂残片 1（二段跳可达）
	_float_platform(10, 4.4, 2.2)
	_add_pickup(Vector3(10, 5.5, 0), Pickup.Kind.SOUL)
	# B
	_platform(19.5, 30, 0.5)
	_hint("J 连击　·　K 重击　·　空中 K 下砸", Vector3(22, 2.8, 0))
	_hint("E 掷出乾坤圈（耗 25 灵力）", Vector3(28, 3.0, 0))
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
	_hint("桥面断开 · 落水会被冲回桥头", Vector3(104, 8.6, 0))
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
	var m := Game.std_mat(Color(0.10, 0.34, 0.40, 0.55), Color(0.16, 0.55, 0.62),
		0.55, 0.22)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
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
	if not (body is Player) or body.dead:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(area.get_meta("cool")) < 2.0:
		return
	area.set_meta("cool", now)
	var x0: float = area.get_meta("x0")
	var x1: float = area.get_meta("x1")
	# 推向更近的一侧桥头，再给一个向上的"被水冲起来"的速度
	var dir := -1.0 if body.global_position.x < (x0 + x1) * 0.5 else 1.0
	body.apply_external_force(Vector3(dir * 7.5, 10.5, 0.0))
	body.take_damage(4, body.global_position.x - dir)
	Game.play_sfx("tide", -6.0, 1.2)
	Game.shake(0.12)


func _build_decor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	# AI 远景：远/中/近三层（固定世界 z，相机平移产生视差）
	var bd := Game.tex("res://art/ref/ch1_corridor.png")
	if bd:
		_build_backdrop_layers(bd, [
			Color(0.86, 0.92, 0.95), Color(0.52, 0.60, 0.64),
			Color(0.22, 0.27, 0.31)], 80.0)
	# 背景断柱长廊
	# 背景断柱长廊停用：远景改由参考图承担，中景柱子由 T17+T18 模块补
	for i in 0:
		var x := -10.0 + i * 7.0 + rng.randf_range(-2.0, 2.0)
		var z := rng.randf_range(-26.0, -9.0)
		_decor_pillar(x, z, rng, i % 3 != 0)
	await get_tree().process_frame
	# 背景巨环（龙宫遗构）
	# 巨环已移除：纵深改由新的柱列 / 栏杆模块承担
	# §4.7：冷青主调里的第二色相——珊瑚橙暖光池，避免整章单一色相
	var warm := OmniLight3D.new()
	warm.light_color = Color(1.0, 0.48, 0.26)
	warm.light_energy = 1.1
	warm.omni_range = 15.0
	warm.omni_attenuation = 1.7
	warm.position = Vector3(78.0, 4.6, -6.0)
	add_child(warm)
	Game.tune_light(warm, 1.1, 15.0, 0.10, 1.7)
	# 水晶
	var crystal_spots: Array = [
		[-5.0, 0.0, 1.6], [10.0, 0.0, -1.8], [27.0, 0.5, 1.8],
		[50.0, 1.0, -1.7], [70.0, 6.0, 1.9], [84.0, 6.0, -1.6],
		[108.0, 6.0, 1.7], [119.0, 6.0, -1.8], [136.0, 2.0, 1.8],
		[158.0, 2.0, -1.6],
	]
	# 水晶已移除：前景细节交给模块化碎石 / 藤壶
	await get_tree().process_frame
	# 海草
	# 海草已移除：与模块化柱列重叠，读成一团
	# 悬空残岩已移除：无支撑的浮石会读成"飘着的纸盒"，在暗场里只挡视线
	# 残灯
	# 旧残灯已移除：改由 T16 石灯笼模块提供
	# 归墟巨涡（Boss 背景）：放到更远处，避免和 Boss 本体在画面上叠成一团
	# 归墟巨涡停用：旧实现是个朝下的暗色大锥体，在画面上读成一块黑色倒三角
	# _decor_vortex(Vector3(158, 8, -36))
	_align_env_to_showcase()


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


# ================================================================ 新环境：模块化结构资产
## 走道 / 栏杆 / 柱 / 灯笼 / 碎石 换成 T16–T24 的 Tripo 结构件。
## 碰撞仍由 LevelBase 的 _platform 提供，这里只替换可见表面。

const ENV_DIR := "res://art/models/glb_game/"
const _ENV_LO := {
	"T16_lantern": "T16_lantern_lo.glb",
	"T17_pillar": "T17_pillar_lo.glb",
	"T18_shaft": "T18_shaft_lo.glb",
	"T19_balustrade": "T19_balustrade_lo.glb",
	"T20_post": "T20_post_lo.glb",
	"T23_rubble": "T23_rubble_lo.glb",
	"T24_barnacle": "T24_barnacle_lo.glb",
}

var _env_cache: Dictionary = {}
var _m_walk: StandardMaterial3D
var _m_wall: StandardMaterial3D
var _m_deep: StandardMaterial3D
var _m_bronze: StandardMaterial3D


func _init_env_mats() -> void:
	if _m_walk != null:
		return
	_m_walk = Game.std_mat(Color(0.105, 0.180, 0.200), Color(0.012, 0.040, 0.048), 0.06, 0.85)
	_m_wall = Game.std_mat(Color(0.072, 0.125, 0.145), Color(0.008, 0.024, 0.030), 0.08, 0.8)
	_m_deep = Game.std_mat(Color(0.040, 0.072, 0.085), Color(0.004, 0.015, 0.020), 0.1, 0.75)
	_m_bronze = Game.std_mat(Color(0.34, 0.26, 0.13), Color(0.0, 0.0, 0.0), 0.3, 0.9)


func _env_scene(key: String) -> PackedScene:
	if _env_cache.has(key):
		return _env_cache[key]
	var file: String = _ENV_LO.get(key, key + ".glb")
	var ps := load(ENV_DIR + file) as PackedScene
	_env_cache[key] = ps
	return ps


func _env_aabb(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var box := m.global_transform * m.get_aabb()
		if first:
			out = box
			first = false
		else:
			out = out.merge(box)
	return out


func _env_tint(root: Node3D, mul: float) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or m.mesh.get_surface_count() == 0:
			continue
		var src := m.get_active_material(0)
		if src is BaseMaterial3D:
			var nm := (src as BaseMaterial3D).duplicate() as BaseMaterial3D
			var c := nm.albedo_color
			nm.albedo_color = Color(c.r * mul, c.g * mul, c.b * mul, c.a)
			m.material_override = nm


func _env_place(key: String, pos: Vector3, h: float, yaw: float = 0.0,
		tint: float = 0.62) -> Node3D:
	## 以 pos 为"底面中心"放置，按目标高度等比缩放。
	var ps := _env_scene(key)
	if ps == null:
		return null
	var n := ps.instantiate() as Node3D
	add_child(n)
	var ab := _env_aabb(n)
	if ab.size.y > 0.0001:
		var s := h / ab.size.y
		n.scale = Vector3(s, s, s)
	n.rotation.y = deg_to_rad(yaw)
	var ab2 := _env_aabb(n)
	n.position += Vector3(
		pos.x - (ab2.position.x + ab2.size.x * 0.5),
		pos.y - ab2.position.y,
		pos.z - (ab2.position.z + ab2.size.z * 0.5))
	_env_tint(n, tint)
	return n


func _dress_walkway(body: StaticBody3D, x0: float, x1: float, ytop: float,
		deep: float) -> void:
	_init_env_mats()
	var w := x1 - x0
	if w < 1.0:
		return
	# 1) 隐藏 LevelBase 原来的大石块（保留碰撞、焦散、符文砖）
	for c in body.get_children():
		if c is MeshInstance3D and c.mesh is BoxMesh:
			if (c.mesh as BoxMesh).size.x > w * 0.8:
				c.visible = false
	# 2) 新走道面 + 立面
	var slab := BoxMesh.new()
	slab.size = Vector3(w, 0.34, 5.0)
	Game.add_mesh(body, slab, _m_walk, Vector3(0, deep * 0.5 - 0.17, 0))
	var lip := BoxMesh.new()
	lip.size = Vector3(w, 0.17, 0.38)
	Game.add_mesh(body, lip, _m_wall, Vector3(0, deep * 0.5 - 0.085, 2.56))
	var band := BoxMesh.new()
	band.size = Vector3(w, 0.055, 0.06)
	Game.add_mesh(body, band, _m_bronze, Vector3(0, deep * 0.5 - 0.30, 2.62))
	var face := BoxMesh.new()
	face.size = Vector3(w, 0.78, 0.20)
	Game.add_mesh(body, face, _m_wall, Vector3(0, deep * 0.5 - 0.56, 2.52))
	var foot := BoxMesh.new()
	foot.size = Vector3(w, 0.22, 0.34)
	Game.add_mesh(body, foot, _m_deep, Vector3(0, deep * 0.5 - 1.02, 2.56))

	# 3) 后沿栏杆（隔段铺，避免整条连续挡住背景）
	if w >= 7.0:
		var seg := 5.2
		var cnt := int(w / seg)
		for i in cnt:
			var bx := x0 + (float(i) + 0.5) * (w / float(maxi(cnt, 1)))
			_env_place("T19_balustrade", Vector3(bx, ytop, -2.12), 1.02,
				0.0, 0.52)
	# 4) 柱列：柱础 + 柱身 + 柱头（断柱高低错落）
	if w >= 9.0:
		var step := 11.0
		var n := int(w / step)
		for i in n:
			var px := x0 + 3.0 + float(i) * step
			if px > x1 - 1.5:
				continue
			var hgt := 2.1 + float((i * 7 + int(x0)) % 5) * 0.42
			var zc := -2.55
			_env_place("T17_pillar", Vector3(px, ytop - 0.06, zc), 0.92, 0.0, 0.50)
			var shaft := _env_place("T18_shaft", Vector3(px, ytop - 0.02, zc), hgt, 0.0, 0.50)
			if shaft != null and hgt > 2.6:
				_env_place("T18_shaft", Vector3(px, ytop - 0.02 + hgt * 0.32, zc),
					hgt * 0.66, 0.0, 0.50)
	# 5) 灯笼（画面边缘节奏点，带暖光）
	if w >= 12.0:
		var lx := x0 + 1.6
		while lx < x1 - 1.6:
			_env_place("T16_lantern", Vector3(lx, ytop, 1.86), 1.32, 0.0, 0.58)
			var lamp := OmniLight3D.new()
			lamp.light_color = Color(1.0, 0.66, 0.34)
			lamp.light_energy = 1.15
			lamp.omni_range = 5.4
			lamp.position = Vector3(lx, ytop + 0.72, 1.80)
			add_child(lamp)
			lx += 24.0
	# 6) 前沿碎石 / 藤壶：只贴立面下沿，不占玩法面
	var rng := RandomNumberGenerator.new()
	rng.seed = int(x0 * 13.0) + int(x1)
	for i in maxi(int(w / 7.0), 1):
		var rx := rng.randf_range(x0 + 0.6, x1 - 0.6)
		_env_place("T23_rubble", Vector3(rx, ytop - 0.86, 2.66),
			rng.randf_range(0.26, 0.44), rng.randf_range(0, 360), 0.46)
		var bx := rng.randf_range(x0 + 0.6, x1 - 0.6)
		_env_place("T24_barnacle", Vector3(bx, ytop - 0.34, 2.60),
			rng.randf_range(0.16, 0.26), rng.randf_range(0, 360), 0.50)


func _platform(x0: float, x1: float, ytop: float, deep := 1.6,
		dark := false) -> StaticBody3D:
	var body := super._platform(x0, x1, ytop, deep, dark)
	_dress_walkway(body, x0, x1, ytop, deep)
	return body


func _align_env_to_showcase() -> void:
	## 让关卡的环境与样板 scene_ch1 一致：ACES + 指数雾 + 同样的体积雾与 ambient。
	var we: WorldEnvironment = null
	for n in get_children():
		if n is WorldEnvironment:
			we = n
			break
	if we == null or we.environment == null:
		return
	var e := we.environment
	# 背景改用纯色：旧的 sky.gdshader 会在画面上方画出一块黑色倒锥
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.020, 0.065, 0.085)
	e.ambient_light_color = Color(0.26, 0.55, 0.64)
	e.ambient_light_energy = 0.42
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 1.05
	e.fog_enabled = true
	e.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	e.fog_light_color = Color(0.06, 0.28, 0.34)
	e.fog_light_energy = 0.40
	e.fog_density = 0.008
	e.fog_aerial_perspective = 0.20
	e.volumetric_fog_enabled = true
	e.volumetric_fog_density = 0.006
	e.volumetric_fog_albedo = Color(0.42, 0.78, 0.86)
	e.volumetric_fog_emission = Color(0.015, 0.08, 0.10)
	e.volumetric_fog_emission_energy = 0.30
	e.volumetric_fog_anisotropy = 0.40
	e.volumetric_fog_length = 55.0
	e.adjustment_enabled = true
	e.adjustment_contrast = 1.08
	e.adjustment_saturation = 1.04
	# 相机画幅也靠近样板：fov 46 → 40，稍微拉平一点透视
	# 调试开关：HIDE_A/HIDE_B 指定要隐藏的子节点下标区间（定位黑锥用）
	var ha := OS.get_environment('HIDE_A')
	if ha != '':
		var a0 := int(ha)
		var a1 := int(OS.get_environment('HIDE_B'))
		var ch := get_children()
		for i in range(maxi(a0, 0), mini(a1, ch.size())):
			var node := ch[i]
			if node is Node3D:
				(node as Node3D).visible = false
	# 收尾：检查点的通光柱是纯黑且巨大的圆柱，近距离会被读成一块黑色倒锥，先关掉
	for mi in find_children('*', 'MeshInstance3D', true, false):
		var m := mi as MeshInstance3D
		if m == null or m.mesh == null:
			continue
		if m.mesh is CylinderMesh and m.get_aabb().size.y > 4.0 and m.global_position.y > 2.0:
			m.visible = false
	if cam != null:
		cam.fov = 44.0
