extends LevelBase
## 第四章 · 龙骨沉殿「潮心」
##
## 176 米，A–H 八段：
##   A 潮门·殿前（−8~18，y0）      教学：卸 / 引潮 / 架
##   B 侧殿潮道（18~42，y0）        顺流 + 逆流两段潮脉
##   C 潮纹殿前（42~64，y0.8）      第一竞技场，清场开门
##   D 龙骨回廊（64~92，y0.8→3.4）  龙肋骨、向上潮脉、潮魇
##   E 潮纹碑（88~102，y0.6）       三碑解谜（非阻塞）
##   F 守潮之庭（104~128，y0.6）    第二竞技场，中央顺流
##   G 殿心前厅（128~152，y0.4）    分潮、莲台、回复
##   H 潮心殿（152~176，y0）        螭吻 Boss
##
## 美术方向：玉青绿 / 骨白 / 朽金，禁用 SSAO / SSR / SDFGI / TAA / DOF。
## 所有危险预警统一走 Game.style_warning_ring()，本文件只摆「喷口」不画红环，
## 红环由 Boss/机关自己在起手时生成，避免常驻红环误导玩家。

const LEN := 176.0

# 共享材质：只在 _make_materials() 里创建一次，所有装饰复用
var mat_bone: StandardMaterial3D
var mat_bone_dark: StandardMaterial3D
var mat_jade: StandardMaterial3D

var _rng := RandomNumberGenerator.new()

# 潮纹碑解谜：基类 TideStele 自带 lit 字段和 light_up()，这里只负责统计
var _steles: Array[Node] = []
var _stele_scan_t := 0.5
var _stele_poll_t := 0.5
var _stele_done := false


# ================================================================ 配置

func _configure() -> void:
	chapter_title = "第四章 · 龙骨沉殿「潮心」"
	chapter_id = "ch4"
	next_scene = ""
	soul_goal = 3
	kill_y = -10.0
	water_y = -11.0
	spawn_wildlife = false

	# 分章调色：玉青绿 → 骨白 → 朽金。
	# 刻意避开 ch1 青蓝、ch2 铁红、ch3 黑紫；阴影里保留一点绿，才能和"潮"同色系。
	grade_shadow_tint = Color(0.76, 1.00, 0.92)
	grade_high_tint = Color(1.06, 1.00, 0.88)
	grade_saturation = 1.05
	grade_contrast = 1.10
	grade_vignette = 0.34
	grade_grain = 0.030

	foreground_end_x = 148.0
	fg_color = Color(0.03, 0.09, 0.07)
	shaft_tint = Color(0.55, 0.95, 0.82)
	shaft_strength = 0.06

	boss_name = "潮心 · 螭吻"
	boss_name_color = Color(0.55, 0.95, 0.82)
	# 立绘：只有真的存在第四章专属头像时才显示，绝不拿第一章的紫脸冒充螭吻
	boss_portrait = "res://art/portrait_boss_ch4.png" \
		if ResourceLoader.exists("res://art/portrait_boss_ch4.png") else ""
	boss_bar_fill = Color(0.24, 0.78, 0.62)
	boss_bar_frame = Color(0.14, 0.46, 0.40)
	boss_defeat_msg = "潮 心 已 定"
	summon_unit = "spawnling"
	portal_msg = "潮心已定 · 龙骨长眠"
	gate_color = Color(0.16, 0.52, 0.44)
	gate_glow = Color(0.35, 0.95, 0.82)

	# 雾色 / 环境光 / 体积雾反照率：A 玉青 → E 骨白 → H 朽金
	zone_stops = [
		[-8.0, Color(0.040, 0.120, 0.100), Color(0.30, 0.54, 0.44),
			Color(0.17, 0.40, 0.32)],
		[42.0, Color(0.060, 0.145, 0.115), Color(0.36, 0.58, 0.46),
			Color(0.21, 0.44, 0.34)],
		[104.0, Color(0.110, 0.135, 0.100), Color(0.55, 0.56, 0.45),
			Color(0.33, 0.40, 0.29)],
		[176.0, Color(0.150, 0.135, 0.085), Color(0.66, 0.58, 0.40),
			Color(0.42, 0.36, 0.22)],
	]

	_rng.seed = 20260419


# ================================================================ 材质

func _make_materials() -> void:
	super._make_materials()

	# 骨白是沉殿的主色：石面提暖、压青，和"龙骨"接上
	mat_stone.albedo_color = Color(0.80, 0.83, 0.73)
	mat_stone_dark.albedo_color = Color(0.36, 0.42, 0.35)
	mat_rock.albedo_color = Color(0.14, 0.19, 0.15)
	mat_trim.albedo_color = Color(0.52, 0.78, 0.62)
	mat_trim.emission = Color(0.14, 0.46, 0.34)
	mat_trim.emission_energy_multiplier = 0.55

	# 晶簇改成玉青 / 朽金，不用 ch1 的紫
	mat_crystal_c.albedo_color = Color(0.20, 0.72, 0.60)
	mat_crystal_c.emission = Color(0.18, 0.85, 0.68)
	mat_crystal_c.emission_energy_multiplier = 0.9
	mat_crystal_p.albedo_color = Color(0.46, 0.37, 0.16)
	mat_crystal_p.emission = Color(0.72, 0.52, 0.20)
	mat_crystal_p.emission_energy_multiplier = 0.20

	# 符文只保留玉青一种，避免满屏多色发光
	mat_rune_c.emission = Color(0.22, 0.80, 0.64)
	mat_rune_c.emission_energy_multiplier = 0.8
	mat_rune_g.emission = Color(0.95, 0.72, 0.30)
	mat_rune_g.emission_energy_multiplier = 0.35

	# 骨材质：微暖、粗糙，不发光；同款全关共享
	# 0.80 的骨白在玉青环境光下会发白发飘，压到 0.66 才有"泡了很久"的重量
	mat_bone = Game.std_mat(Color(0.66, 0.63, 0.53),
		Color(0.04, 0.05, 0.04), 0.08, 0.78)
	mat_bone.rim_enabled = true
	mat_bone.rim = 0.22
	mat_bone.rim_tint = 0.45
	mat_bone_dark = Game.std_mat(Color(0.36, 0.38, 0.32),
		Color(0.03, 0.05, 0.04), 0.08, 0.85)
	mat_jade = Game.std_mat(Color(0.08, 0.30, 0.24),
		Color(0.20, 0.65, 0.50), 0.55, 0.35)


# ================================================================ 环境

func _build_environment() -> void:
	# 不用基类的冷蓝 Environment：这章是"沉在龙骨里的玉青水殿"。
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.020, 0.055, 0.045)
	env.background_energy_multiplier = 0.7
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.50, 0.42)
	env.ambient_light_energy = 0.55
	env.ambient_light_sky_contribution = 0.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.50
	env.glow_hdr_luminance_cap = 8.0
	env.set("glow_levels/1", 0.8)
	env.set("glow_levels/2", 1.0)
	env.set("glow_levels/3", 0.35)
	env.set("glow_levels/4", 0.1)
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.045, 0.120, 0.100)
	env.fog_light_energy = 1.0
	env.fog_depth_begin = 8.0
	env.fog_depth_end = 120.0
	env.fog_depth_curve = 1.4
	env.fog_height = 7.0
	env.fog_height_density = 0.05
	env.fog_aerial_perspective = 0.40
	env.fog_sky_affect = 0.15
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.009
	env.volumetric_fog_albedo = Color(0.22, 0.42, 0.34)
	env.volumetric_fog_emission = Color(0.010, 0.035, 0.025)
	env.volumetric_fog_emission_energy = 0.30
	env.volumetric_fog_anisotropy = 0.55
	env.volumetric_fog_length = 90.0
	env.volumetric_fog_ambient_inject = 0.40
	env.ssao_enabled = false
	env.ssr_enabled = false
	env.sdfgi_enabled = false
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.10
	env.adjustment_saturation = 1.04

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	_env = env

	# 顶部冷白主光：穿过水面的"天光"，影子只保近处
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(0.80, 0.98, 0.90)
	sun.light_energy = 2.20
	sun.light_volumetric_fog_energy = 1.20
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 32.0
	sun.shadow_bias = 0.06
	sun.shadow_normal_bias = 1.5
	sun.rotation_degrees = Vector3(-58.0, 26.0, 0.0)
	add_child(sun)
	_sun = sun

	# 玉青侧光：给骨柱和肋骨一点冷绿边
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.28, 0.78, 0.62)
	fill.light_energy = 0.38
	fill.light_volumetric_fog_energy = 0.0
	fill.rotation_degrees = Vector3(22.0, 152.0, 0.0)
	add_child(fill)

	# 朽金逆光：只照 Boss 段，让"潮心"在水雾里发暖
	var warm := DirectionalLight3D.new()
	warm.light_color = Color(0.95, 0.70, 0.32)
	warm.light_energy = 0.22
	warm.light_volumetric_fog_energy = 0.0
	warm.rotation_degrees = Vector3(8.0, -34.0, 0.0)
	add_child(warm)


func _build_water() -> void:
	# 潮水只做视觉：A/B/H 三段落水面，不阻挡、不参与碰撞。
	_tide_water(-8.0, 20.0, -0.35)
	_tide_water(20.0, 44.0, -0.45)
	_tide_water(128.0, 176.0, -0.35)


func _update_zone_ambience(delta: float) -> void:
	# 覆盖基类的"青蓝→铁红"太阳渐变：这章是玉青→朽金。
	if player == null or not is_instance_valid(player) or _env == null:
		return
	var s := _zone_sample(player.global_position.x)
	var k := clampf(2.5 * delta, 0.0, 1.0)
	_env.fog_light_color = _env.fog_light_color.lerp(s[0], k)
	_env.ambient_light_color = _env.ambient_light_color.lerp(s[1], k)
	_env.volumetric_fog_albedo = _env.volumetric_fog_albedo.lerp(s[2], k)
	var t := clampf((player.global_position.x - 60.0) / 100.0, 0.0, 1.0)
	var sun_c := Color(0.78, 0.98, 0.90).lerp(Color(1.00, 0.80, 0.45), t)
	if _sun:
		_sun.light_color = _sun.light_color.lerp(sun_c, k)


# ================================================================ 流程

func _build_layout() -> void:
	_build_terrain()
	await get_tree().process_frame
	await _build_decor()
	await get_tree().process_frame
	_build_props()
	# 前景剪影按基类注释暂时不做：黑纸片会毁观感，等 AI alpha 素材再补。


func _process(delta: float) -> void:
	super._process(delta)
	# 潮纹碑由基类动态生成；用 group 抓取，避免对 TideStele 的编译期依赖。
	if _steles.is_empty():
		_stele_scan_t -= delta
		if _stele_scan_t <= 0.0:
			_stele_scan_t = 0.5
			_steles = get_tree().get_nodes_in_group("tide_stele")
	if _steles.is_empty() or _stele_done:
		return
	_stele_poll_t -= delta
	if _stele_poll_t > 0.0:
		return
	_stele_poll_t = 0.5
	_check_stele_puzzle()


# ================================================================ 地形

func _build_terrain() -> void:
	# ---------------- A 潮门·殿前（−8~20）：三级骨阶，走到殿门再落回地面 ----------------
	# 原来 A 是一整条 y0 的平台，和前三章开场几乎一样；现在用"上三级、下两级"
	# 的骨阶把入口做成一段有起伏的引道。
	_platform(-8.0, 6.0, 0.0)
	_platform(6.0, 10.0, 0.5)
	_platform(10.0, 14.0, 1.0)
	_platform(14.0, 18.0, 0.5)
	_platform(18.0, 20.0, 0.0)
	_add_checkpoint(Vector3(-4.0, 0.0, 0.0), true)
	_add_pickup(Vector3(3.0, 1.1, 0.0), Pickup.Kind.ENERGY)
	_add_pickup(Vector3(15.0, 1.7, 0.0), Pickup.Kind.SOUL)
	# 三条教学，严格按"先卸、再引潮、最后架"的顺序，且不设必须弹反的墙
	_hint("「卸」：潮弹将至，按住防御把它卸回去", Vector3(9.5, 0.5, 0.0))
	_hint("「引潮」：长按聚潮，把散落的潮弹引成齐射", Vector3(14.0, 0.5, 0.0))
	_hint("「架」：潮生扑咬的起手亮起时，架住它", Vector3(17.0, 0.5, 0.0))
	_invisible_wall(-8.4, 0.0, 12.0)

	# ---------------- B 侧殿潮道（20~42）：整段下沉 1.2m 的潮沟 ----------------
	# 前三章的"平地 + 浮台"在这里断掉：玩家要跳进沟里逆流走一段，再跳回岸。
	_platform(20.0, 24.0, 0.0)
	_platform(24.0, 32.0, -1.2)
	_platform(32.0, 34.0, -0.6)   # 出水两级台阶：一次跳 1.2m 的直墙容易贴着墙跳不上去
	_platform(34.0, 42.0, 0.0)
	_tide_current(24.6, 31.4, -1.0, 2.4, Vector3(CURRENT_FORCE, 0.0, 0.0))
	_tide_current(34.0, 40.0, 0.2, 2.6, Vector3(-CURRENT_FORCE, 0.0, 0.0))
	# 沟里两根断柱：既是"这里塌过"的叙事，也给跳跃一个参照物
	_decor_pillar(25.6, -3.6, _rng)
	_decor_pillar(30.4, 3.6, _rng)
	_add_pickup(Vector3(27.0, -0.1, 0.0), Pickup.Kind.ENERGY)
	_hint("顺流：潮脉会推着你走；逆流段要抢在推力前上台阶",
		Vector3(21.5, 0.0, 0.0))

	# ---------------- C 潮纹殿前（42~64，y0.8） ----------------
	_platform(42.0, 64.0, 0.8)
	_add_checkpoint(Vector3(43.0, 0.8, 0.0))
	_spikes(55.0, 57.0, 0.8)
	_add_pickup(Vector3(49.5, 1.9, 0.0), Pickup.Kind.ENERGY)
	_add_pickup(Vector3(59.0, 1.9, 0.0), Pickup.Kind.ENERGY)
	_hint("潮纹殿前 · 清尽潮兽，入口与出口的封印才会同时打开",
		Vector3(45.0, 0.8, 0.0))

	# ---------------- D 龙骨回廊（64~92，y0.8→3.4，中间一道断口） ----------------
	_platform(64.0, 74.0, 0.8)
	# 74~75.6 是一道"塌下去的断口"：不是无底深渊，掉进去只会落低 0.8m，
	# 再跳上来就行——走廊里做即死断崖太劝退。
	_platform(74.0, 75.6, 0.0)
	_platform(75.6, 82.0, 1.6)
	_platform(82.0, 87.0, 2.4)
	_platform(87.0, 92.0, 3.4)
	_add_checkpoint(Vector3(66.0, 0.8, 0.0))
	# 向上潮脉：把玩家从 1.6 的台阶托到 4.6 的骨台（龙魂在顶端）
	_tide_current(77.5, 82.5, 1.6, 3.8, Vector3(0.0, CURRENT_FORCE, 0.0))
	_bone_shelf(80.0, 4.6, 3.2)
	_add_pickup(Vector3(80.0, 5.8, 0.0), Pickup.Kind.SOUL)
	_hint("潮脉向上 · 借流登骨，龙魂在最高处", Vector3(77.0, 1.6, 0.0))

	# ---------------- E 潮纹碑（90~104，y0.6） ----------------
	_platform(90.0, 104.0, 0.6)
	# 三碑间距 2.6：站在两碑之间、面朝左，卸回"背后"落下的潮弹即可依次点亮
	_decor_tide_stele(Vector3(93.4, 0.6, 0.0))
	_decor_tide_stele(Vector3(96.0, 0.6, 0.0))
	_decor_tide_stele(Vector3(98.6, 0.6, 0.0))
	_add_pickup(Vector3(100.6, 1.7, 0.0), Pickup.Kind.SOUL)
	_add_pickup(Vector3(101.4, 1.7, 0.0), Pickup.Kind.HEAL)
	_hint("潮纹碑 · 面朝碑身，卸回守碑浮母落下的潮弹", Vector3(92.0, 0.6, 0.0))

	# ---------------- F 守潮之庭（104~128，y0.6，中间一道落水坑） ----------------
	_platform(104.0, 116.0, 0.6)
	_platform(116.0, 119.0, -0.6)
	_platform(119.0, 121.0, 0.0)  # 同 B 段：坑底到台面拆成两级
	_platform(121.0, 128.0, 0.6)
	_add_checkpoint(Vector3(106.0, 0.6, 0.0))
	_tide_current(112.0, 120.0, 0.8, 2.6, Vector3(5.0, 3.3, 0.0))
	_add_pickup(Vector3(111.0, 1.7, 0.0), Pickup.Kind.ENERGY)
	_hint("守潮之庭 · 中央斜向潮脉会把你推向右上，别被送进守门潮生的扑咬里",
		Vector3(108.0, 0.6, 0.0))

	# ---------------- G 殿心前厅（128~152，y0.4 → 0） ----------------
	_platform(128.0, 150.0, 0.4)
	_platform(150.0, 152.0, 0.0)
	_add_checkpoint(Vector3(147.0, 0.4, 0.0))
	_bone_shelf(140.0, 0.9, 2.6)
	_add_pickup(Vector3(140.0, 2.1, 0.0), Pickup.Kind.ENERGY)
	_add_pickup(Vector3(149.5, 1.2, 0.0), Pickup.Kind.HEAL)
	_hint("潮心殿 · 螭吻就在门后，先在莲台把血补满", Vector3(150.0, 0.0, 0.0))

	# ---------------- H 潮心殿（152~176，y0） ----------------
	_platform(152.0, 176.0, 0.0, 2.6)
	# Boss 场刻意留白：不放浮台，追击镜头才不会被石板切掉半屏。
	_add_pickup(Vector3(162.0, 1.5, 0.0), Pickup.Kind.HEAL)
	_invisible_wall(176.4, 0.0, 14.0)


func _decor_spine_run(x0: float, x1: float, y: float) -> void:
	## 头顶的龙骨脊椎：一串椎骨 + 每隔一节向两侧垂下的短肋。
	## 侧视走廊里，只有"沿 x 方向"的骨架才读得出曲线；横跨 z 的肋拱会被看成散落的木板。
	var bone := Game.std_mat(Color(0.30, 0.29, 0.24), Color(0.01, 0.03, 0.03),
		0.05, 0.95)
	var n := maxi(3, int((x1 - x0) / 1.1))
	var vertebra := BoxMesh.new()
	vertebra.size = Vector3(0.44, 0.30, 0.62)
	var rib := CylinderMesh.new()
	rib.top_radius = 0.035
	rib.bottom_radius = 0.055
	rib.height = 1.9
	rib.radial_segments = 5
	var fin := BoxMesh.new()
	fin.size = Vector3(0.10, 0.42, 0.30)
	for i in n + 1:
		var t := float(i) / float(n)
		var x := lerpf(x0, x1, t)
		var sway := sin(t * 7.0) * 0.28
		var vy := y + sway
		var mi := Game.add_mesh(self, vertebra, bone, Vector3(x, vy, 0.0))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# 背鳍
		Game.add_mesh(self, fin, bone, Vector3(x, vy + 0.34, 0.0))
		# 每两节一对短肋，向两侧斜垂，避免正中间挡视线
		if i % 2 == 0:
			for sz: float in [-1.0, 1.0]:
				var a: float = 0.55 * sz
				Game.add_mesh(self, rib, bone, Vector3(x, vy - 0.92, sz * 0.62),
					Vector3(0.0, 0.0, rad_to_deg(a) * -1.0))


func _bone_shelf(x: float, ytop: float, w: float) -> StaticBody3D:
	## 高处骨台：不再是"凭空浮着的方盒"，下面接一根收分的骨柱 + 四片肋鳍，
	## 让它在剪影里属于"龙骨"的一部分，而不是一块石头。
	var body := _platform(x - w * 0.5, x + w * 0.5, ytop, 0.55)
	var col := CylinderMesh.new()
	col.top_radius = 0.30
	col.bottom_radius = 1.05
	col.height = maxf(ytop, 0.8)
	col.radial_segments = 7
	Game.add_mesh(self, col, mat_bone, Vector3(x, ytop * 0.5 - 0.15, 0.0))
	var fin := BoxMesh.new()
	fin.size = Vector3(0.16, 1.4, 0.5)
	for i in 4:
		var ang := -0.9 + 0.6 * float(i)
		Game.add_mesh(self, fin, mat_bone_dark,
			Vector3(x + cos(ang) * 0.95, ytop * 0.5 + 0.2, sin(ang) * 0.95),
			Vector3(0.0, rad_to_deg(ang), 16.0 if i % 2 == 0 else -16.0))
	return body

# ================================================================ 装饰

func _build_decor() -> void:
	_rng.seed = 20260419

	# 背景：优先用第四关专属 backdrop，缺失时用渐变兜底（不报错）
	if ResourceLoader.exists("res://art/backdrop_ch4.png"):
		var tex := Game.tex("res://art/backdrop_ch4.png")
		if tex:
			var quad := QuadMesh.new()
			quad.size = Vector2(300.0, 120.0)
			var bm := StandardMaterial3D.new()
			bm.albedo_texture = tex
			bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			bm.emission_enabled = true
			bm.emission = Color(0.24, 0.38, 0.32)
			bm.emission_energy_multiplier = 0.32
			Game.add_mesh(self, quad, bm, Vector3(84.0, 10.0, -58.0))
	else:
		_fallback_backdrop()

	_build_light_shafts()

	# 龙骨脊：D 段头顶串起 8 节椎骨（同一 mesh/material，避免循环里建材质）
	var vert := CylinderMesh.new()
	vert.top_radius = 0.26
	vert.bottom_radius = 0.36
	vert.height = 0.55
	vert.radial_segments = 6
	for i in 8:
		var x := 64.0 + i * 4.0
		Game.add_mesh(self, vert, mat_bone, Vector3(x, 8.4, 0.0),
			Vector3(0.0, 0.0, 90.0))

	# 肋骨：只留远处一对做剪影。原本在 70/82 各放一对，近看是一排"奶油色脚手架"，
	# 反而把 D 段的骨架节奏读乱了（骨拱 + 头顶椎骨已经够交代"龙骨"）。
	# 头顶的龙骨脊椎不放：相机压得很低，头顶装饰只会变成乱插的木棍

	# 骨拱：切分四段空间节奏（A/C/E/H 入口），全用局部共享骨材质
	_bone_arch(42.5, 0.8, 6.4, 6.8)
	_bone_arch(104.5, 0.6, 6.4, 6.8)
	_bone_arch(153.5, 0.0, 8.0, 7.8)
	_bone_arch(174.5, 0.0, 8.0, 7.8)

	# 断柱 / 灯笼 / 晶簇 / 浮石：全部复用基类装饰器
	_decor_pillar(6.0, -3.8, _rng)
	_decor_pillar(40.0, -3.8, _rng)
	_decor_pillar(90.0, -3.8, _rng)
	_decor_pillar(140.0, -3.8, _rng)

	_decor_lantern(Vector3(20.0, 2.4, 3.6))
	_decor_lantern(Vector3(44.0, 3.0, 3.6))
	_decor_lantern(Vector3(106.0, 2.8, 3.6))
	_decor_lantern(Vector3(150.0, 2.4, 3.6))

	_decor_crystal(Vector3(10.0, 0.0, -3.6), true, _rng, false)
	_decor_crystal(Vector3(57.0, 0.8, -3.6), true, _rng, false)
	_decor_crystal(Vector3(84.0, 2.4, -3.8), true, _rng, false)
	_decor_crystal(Vector3(118.0, 0.6, -3.8), true, _rng, false)
	_decor_crystal(Vector3(145.0, 0.4, -3.8), false, _rng, false)

	# 不再放"悬空石块"：玩家反馈这类无支撑的浮石读成飘着的纸盒，
	# 遮挡视线又没有任何交互意义，这里改为让视线直接落到龙骨与光柱上。
	# Boss 场四处潮柱喷口：只摆"铁栅 + 玉青微光"，不常驻红环；
	# 真正的红外预警环由 Boss 的潮柱起手自己生成。
	_build_tide_vents()

	await get_tree().process_frame


func _fallback_backdrop() -> void:
	# 美术资源尚未接入时的兜底：一张 300×120 的竖向渐变，不写死贴图路径
	var grad := Gradient.new()
	grad.add_point(0.0, Color(0.015, 0.050, 0.042))
	grad.add_point(0.55, Color(0.040, 0.120, 0.095))
	grad.add_point(1.0, Color(0.110, 0.125, 0.080))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.width = 8
	gt.height = 64
	gt.fill_from = Vector2(0.0, 0.0)
	gt.fill_to = Vector2(0.0, 1.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = gt
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(0.10, 0.20, 0.15)
	mat.emission_energy_multiplier = 0.30
	var quad := QuadMesh.new()
	quad.size = Vector2(300.0, 120.0)
	Game.add_mesh(self, quad, mat, Vector3(84.0, 10.0, -58.0))


func _build_light_shafts() -> void:
	# 水下光柱：单个圆柱 mesh + 单个加法材质，循环里只复制实例
	var shaft := CylinderMesh.new()
	shaft.top_radius = 1.5
	shaft.bottom_radius = 0.5
	shaft.height = 30.0
	shaft.radial_segments = 6
	shaft.cap_top = false
	shaft.cap_bottom = false
	var sm := Game.std_mat(Color(0.40, 0.90, 0.78, 0.055),
		Color(0.40, 0.90, 0.78), 0.35, 1.0)
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	for x in [10.0, 46.0, 86.0, 120.0, 158.0]:
		Game.add_mesh(self, shaft, sm, Vector3(x, 14.0, -34.0))


func _build_tide_vents() -> void:
	# 四个喷口是 Boss 潮柱的"落点提示物"，不是预警本身
	var grate := CylinderMesh.new()
	grate.top_radius = 0.62
	grate.bottom_radius = 0.74
	grate.height = 0.16
	grate.radial_segments = 8
	var ring := TorusMesh.new()
	ring.inner_radius = 0.72
	ring.outer_radius = 0.86
	ring.rings = 16
	ring.ring_segments = 4
	for x in [156.0, 160.0, 168.0, 172.0]:
		Game.add_mesh(self, grate, mat_stone_dark, Vector3(x, 0.08, 0.0))
		Game.add_mesh(self, ring, mat_jade, Vector3(x, 0.10, 0.0))


func _bone_arch(x: float, ground_y: float, span: float,
		height: float) -> void:
	# 局部骨拱：单位 Box 共享 mesh，靠 scale 拉成柱/梁，材质复用 mat_bone*
	var unit := BoxMesh.new()
	unit.size = Vector3.ONE
	var half := span * 0.5
	for side in [-1.0, 1.0]:
		Game.add_mesh(self, unit, mat_bone_dark,
			Vector3(x + side * half, ground_y + height * 0.5, -3.4),
			Vector3.ZERO, Vector3(0.55, height, 0.55))
	Game.add_mesh(self, unit, mat_bone,
		Vector3(x, ground_y + height, -3.4),
		Vector3.ZERO, Vector3(span + 0.7, 0.35, 0.55))
	Game.add_mesh(self, unit, mat_jade,
		Vector3(x, ground_y + height + 0.28, -3.4),
		Vector3(0.0, 45.0, 0.0), Vector3(0.30, 0.30, 0.30))


# ================================================================ 道具

func _build_props() -> void:
	# 龙首雕像：Boss 场压轴。别放在 164 正后方——螭吻悬浮在 164，两者会重叠成一团，
	# 挪到 173 偏侧后方，只当背景剪影。
	var statue := _prop(PROP_STATUE, 7.0, 180.0, 0.0)
	if statue:
		statue.position = Vector3(173.0, 0.0, -8.5)
		add_child(statue)
		# 基类默认会加冷紫自发光，这里换回玉青微光（≤0.35）
		_tune_prop_materials(statue, Color(0.06, 0.20, 0.16), 0.22,
			Color(0.72, 0.74, 0.66))

	# 吊灯：潮心殿顶部的朽金光源
	var chand_a := _prop(PROP_CHANDELIER, 2.8, 0.0, 0.0)
	if chand_a:
		chand_a.position = Vector3(160.0, 8.2, 0.0)
		add_child(chand_a)
		_tune_prop_materials(chand_a, Color(0.30, 0.22, 0.08), 0.30)
	var chand_b := _prop(PROP_CHANDELIER, 2.8, 0.0, 0.0)
	if chand_b:
		chand_b.position = Vector3(170.0, 8.2, 0.0)
		add_child(chand_b)
		_tune_prop_materials(chand_b, Color(0.30, 0.22, 0.08), 0.30)


# ================================================================ 战斗

func _build_encounters() -> void:
	# A 教学：炮台先教会"卸"，潮生再教会"架"
	_spawn_turret(12.0, 0.0)
	_spawn_spawnling(16.5, 0.0, 12.0, 17.5)
	await get_tree().process_frame

	# B 侧殿潮道：两只爬行者把玩家往潮脉里逼
	_spawn_crawler(21.0, 0.0, 19.0, 23.0)
	_spawn_crawler(31.0, 0.0, 29.0, 34.0)
	await get_tree().process_frame

	# C 第一竞技场：炮台 + 浮母 + 水母 + 潮生
	# 加一只浮母：竞技场里必须"有弹可以卸"，否则玩家只会贴脸砍完走人。
	_lock_arena(62.0, 0.8, 47.0, [
		func() -> EnemyBase: return _spawn_turret(50.0, 0.8),
		func() -> EnemyBase: return _spawn_bomber(53.0, 2.8),
		func() -> EnemyBase: return _spawn_shooter(55.0, 3.6, 44.0, 61.0),
		func() -> EnemyBase: return _spawn_spawnling(58.0, 0.8, 54.0, 61.0),
	], "潮纹殿前")

	# D 龙骨骇廊：潮魇在骨架上盘旋
	_spawn_wraith(84.0, 5.4, 80.0, 90.0)

	# E 守碑浮母：唯一稳定的"可卸"弹源，位置高，弹道从碑顶越过
	_spawn_shooter(102.0, 6.2, 1.0, 16.0)

	# F 第二竞技场：三只怪 + 两台炮台 + 中央顺流
	_lock_arena(126.0, 0.6, 110.5, [
		func() -> EnemyBase: return _spawn_wraith(113.0, 3.2, 110.0, 122.0),
		func() -> EnemyBase: return _spawn_bomber(117.0, 2.8),
		func() -> EnemyBase: return _spawn_turret(114.0, 0.6),
		func() -> EnemyBase: return _spawn_shooter(121.0, 1.4, 108.0, 124.0),
		func() -> EnemyBase: return _spawn_spawnling(124.0, 0.6, 116.0, 125.0),
	], "守潮之庭")
	await get_tree().process_frame

	# G 前厅：分潮可选，不打也能过
	_spawn_divider(137.0, 0.4, 132.0, 142.0)
	await get_tree().process_frame

	_build_boss()


func _build_boss() -> void:
	# BossChiwen 在 scripts/boss_chiwen.gd（class_name BossChiwen），本文件不定义它
	var b := BossChiwen.new()
	# 螭吻本身没有重力：y 必须正好摆在神台上（H 段地面 y=0），
	# 模型自身从 y≈2 起才有躯体，所以这里不能抬高，否则地面特效与判定会错位。
	b.position = Vector3(164.0, 0.0, 0.0)
	add_child(b)
	_setup_boss(b, boss_name, 152.0, 176.0, 0.0, 151.4, 153.5)


func _on_boss_summon(count: int) -> void:
	# 基类的召唤分派表里还没有 "spawnling"，这里补上；
	# 同时在旧基类上保持可用（其余 summon_unit 交回基类处理）。
	if summon_unit != "spawnling":
		super._on_boss_summon(count)
		return
	hud.show_message("潮心低语 · 潮生自水底爬出……", 1.6, 36)
	for i in count:
		var x := lerpf(arena_min_x + 5.0, arena_max_x - 5.0,
			float(i) / maxf(count - 1, 1))
		var e := _spawn_spawnling(x, arena_ground_y,
			arena_min_x + 1.5, arena_max_x - 1.5)
		Game.burst(self, e.global_position, Color(0.35, 0.90, 0.80),
			20, 5.0, 0.08, 0.6)
		_boss_summons.append(e)


# ================================================================ 潮纹碑解谜

func _check_stele_puzzle() -> void:
	var lit := 0
	for n in _steles:
		if is_instance_valid(n) and "lit" in n and bool(n.get("lit")):
			lit += 1
	if lit < _steles.size():
		return
	_stele_done = true
	# 三碑全亮：Stele 自己已经给了灵力珠，这里只补一次总反馈，不再叠加奖励
	hud.show_message("潮纹共鸣 · 三碑俱亮", 2.0, 40)
	Game.burst(self, Vector3(96.0, 2.4, 0.0), Color(0.40, 0.95, 0.85),
		40, 6.0, 0.08, 0.8)
