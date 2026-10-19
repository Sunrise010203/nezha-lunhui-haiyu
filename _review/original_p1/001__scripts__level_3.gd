extends LevelBase
## 第三章 · 归墟虚空「海眼」
## 内容：虚空浮岛（混天绫教学）→ 断环深渊 → 螺旋回廊（引力井）→ 第一竞技场
##      → 海眼回廊（摆荡 + 引力井）→ 悬空祭坛 → 第二竞技场 → 海眼前厅 → Boss「归墟海眼」
## 新机制：F 混天绫（抓铜环摆荡 / 缠敌拉拽）+ 海眼引力井。
## 场景刻意与一/二章区分：没有宫殿背景、没有石柱海草与水面，
## 只有黑色虚空、漂浮的封印石板、残骸与光柱。

const LEN := 172.0


func _configure() -> void:
	chapter_title = "第三章 · 归墟虚空「海眼」"
	chapter_id = "ch3"
	next_scene = ""                      # 每关独立：通关只结算本章
	soul_goal = 3
	# 台面下方是归墟虚空，掉下去比前两章更深
	kill_y = -10.0
	water_y = -11.0
	spawn_wildlife = false
	boss_name = "归墟海眼"
	boss_name_color = Color(0.55, 0.9, 1.0)
	summon_unit = "wraith"               # 海眼召唤的是潮魇
	boss_portrait = ""
	boss_defeat_msg = "海 眼 暂 闭 · 封 印 复 位"
	portal_msg = "归墟回响之门已开 · 可返回选关"
	# 封印门：珍珠青白（区别于第一章紫、第二章狱火橙）
	gate_color = Color(0.26, 0.56, 0.64)
	gate_glow = Color(0.20, 0.50, 0.55)
	# 归墟虚空：近黑紫 → 深渊紫 → 海眼珍珠青
	zone_stops = [
		[0.0, Color(0.075, 0.045, 0.13), Color(0.24, 0.20, 0.40),
			Color(0.30, 0.22, 0.52)],
		[52.0, Color(0.090, 0.045, 0.15), Color(0.26, 0.19, 0.42),
			Color(0.34, 0.21, 0.56)],
		[104.0, Color(0.110, 0.045, 0.16), Color(0.29, 0.19, 0.44),
			Color(0.40, 0.22, 0.60)],
		[140.0, Color(0.140, 0.050, 0.18), Color(0.33, 0.21, 0.48),
			Color(0.48, 0.26, 0.66)],
		[158.0, Color(0.170, 0.060, 0.20), Color(0.38, 0.24, 0.52),
			Color(0.56, 0.30, 0.72)],
	]
	# 关卡机制需要在本关的玩家节点之后处理（引力井）
	process_physics_priority = 100


# ================================================================ 材质 / 环境

func _make_materials() -> void:
	super._make_materials()
	## 归墟虚空：不是石造宫殿，而是"漂浮的封印黑曜石板"
	## 关键是与第一章区分：去掉石材三向贴图、压到近黑，只留青白发光边
	for m: StandardMaterial3D in [mat_stone, mat_stone_dark, mat_rock]:
		m.albedo_texture = null
		m.uv1_triplanar = false
	mat_stone.albedo_color = Color(0.15, 0.13, 0.22)
	mat_stone.roughness = 0.45
	mat_stone.metallic = 0.25
	# 边缘光：黑曜石板的边界在虚空里必须看得见
	mat_stone.rim_enabled = true
	mat_stone.rim = 0.45
	mat_stone.rim_tint = 0.8
	mat_stone_dark.albedo_color = Color(0.07, 0.06, 0.12)
	mat_stone_dark.roughness = 0.5
	mat_stone_dark.rim_enabled = true
	mat_stone_dark.rim = 0.35
	mat_stone_dark.rim_tint = 0.7
	mat_rock.albedo_color = Color(0.07, 0.06, 0.11)
	mat_rock.roughness = 0.7
	# 描边：珍珠青白，暗底上更亮
	mat_trim.albedo_color = Color(0.24, 0.52, 0.55)
	mat_trim.emission = Color(0.35, 0.62, 0.68)
	mat_trim.emission_energy_multiplier = 0.25
	# 尖刺危险物：虚空整体是紫黑，危险物必须用高饱和的赤紫，一眼分辨
	mat_coral.albedo_color = Color(0.62, 0.16, 0.30)
	mat_coral.emission = Color(1.0, 0.22, 0.45)
	mat_coral.emission_energy_multiplier = 0.85
	mat_crystal_c.albedo_color = Color(0.72, 0.92, 0.98, 0.9)
	mat_crystal_c.emission = Color(0.70, 0.95, 1.0)
	mat_crystal_c.emission_energy_multiplier = 0.45
	mat_crystal_p.albedo_color = Color(0.60, 0.48, 0.92, 0.9)
	mat_crystal_p.emission = Color(0.55, 0.35, 0.95)
	mat_crystal_p.emission_energy_multiplier = 0.45
	mat_gold.albedo_color = Color(0.62, 0.55, 0.36)
	mat_gold.emission = Color(0.45, 0.34, 0.12)
	mat_rune_c.albedo_color = Color(0.22, 0.50, 0.55)
	mat_rune_c.emission = Color(0.35, 0.85, 0.95)
	mat_rune_c.emission_energy_multiplier = 0.30
	mat_rune_g.albedo_color = Color(0.46, 0.42, 0.30)
	mat_rune_g.emission = Color(0.55, 0.45, 0.18)


func _build_environment() -> void:
	## 不调用 super：归墟虚空没有天空、没有水面，是"秩序消解后的黑色空间"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.034, 0.024, 0.062)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.30, 0.26, 0.46)
	env.ambient_light_energy = 0.60
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.5
	env.glow_hdr_luminance_cap = 8.0
	env.set("glow_levels/1", 0.8)
	env.set("glow_levels/2", 1.0)
	env.set("glow_levels/3", 0.4)
	env.set("glow_levels/4", 0.1)
	env.set("glow_levels/5", 0.0)
	env.set("glow_levels/6", 0.0)
	env.set("glow_levels/7", 0.0)
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.10, 0.06, 0.20)
	env.fog_light_energy = 0.75
	env.fog_density = 0.016
	env.fog_aerial_perspective = 0.5
	env.fog_sky_affect = 0.2
	env.fog_height = 4.0
	env.fog_height_density = 0.06
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.008
	env.volumetric_fog_albedo = Color(0.34, 0.28, 0.56)
	env.volumetric_fog_emission = Color(0.05, 0.02, 0.11)
	env.volumetric_fog_emission_energy = 0.35
	env.volumetric_fog_anisotropy = 0.6
	env.volumetric_fog_length = 80.0
	env.volumetric_fog_ambient_inject = 0.55
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.14
	env.adjustment_saturation = 0.98
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	_env = env
	# 从上往下照的"珍珠光"：虚空里唯一的方向光源
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(0.78, 0.92, 1.0)
	sun.light_energy = 1.30
	sun.light_volumetric_fog_energy = 1.3
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 30.0
	sun.shadow_bias = 0.06
	sun.shadow_normal_bias = 1.5
	sun.rotation_degrees = Vector3(-62, 22, 0)
	add_child(sun)
	_sun = sun
	# 下方深渊的紫色反射
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.42, 0.24, 0.72)
	fill.light_energy = 0.55
	fill.rotation_degrees = Vector3(38, 160, 0)
	add_child(fill)


func _build_water() -> void:
	## 归墟虚空没有水面：改成远处一张极暗的"渊底"渐变面，只提供纵深
	var quad := QuadMesh.new()
	quad.size = Vector2(420, 180)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.02, 0.012, 0.045)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.disable_receive_shadows = true
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(80, -30, -60)
	add_child(mi)


func _process(delta: float) -> void:
	super._process(delta)
	# 离海眼越近，镜头越压低，露出下方深渊
	if cam == null or player == null or boss_started:
		return
	var deep := clampf((player.global_position.x - 60.0) / 100.0, 0.0, 1.0)
	cam.set_framing(2.2 * deep, -1.6 * deep)


func _update_zone_ambience(delta: float) -> void:
	## 覆盖基类：虚空的"日光"是自上而下漂移的珍珠光，末段偏紫，不是基类的红光
	if player == null or not is_instance_valid(player) or _env == null:
		return
	var s := _zone_sample(player.global_position.x)
	var k := clampf(2.5 * delta, 0.0, 1.0)
	_env.fog_light_color = _env.fog_light_color.lerp(s[0], k)
	_env.ambient_light_color = _env.ambient_light_color.lerp(s[1], k)
	_env.volumetric_fog_albedo = _env.volumetric_fog_albedo.lerp(s[2], k)
	var t := clampf(player.global_position.x / 172.0, 0.0, 1.0)
	var sun_c := Color(0.78, 0.92, 1.0).lerp(Color(0.92, 0.58, 0.86), t)
	if _sun:
		_sun.light_color = _sun.light_color.lerp(sun_c, k)


func _start_boss() -> void:
	if boss == null or boss_started or boss.dead:
		return
	super._start_boss()
	cam.set_framing(1.4, 0.6)


# ================================================================ 地形 + 装饰

func _build_layout() -> void:
	_build_terrain()
	_void_edge_glow()
	await get_tree().process_frame
	await _build_decor()
	await get_tree().process_frame
	_foreground_shards()
	_build_props()


func _build_terrain() -> void:
	# A 祭坛前庭（地面 0）：混天绫教学
	_platform(-8, 18, 0.0)
	_add_checkpoint(Vector3(-4, 0, 0), true)
	_hint("F 混天绫 —— 抓向空中的铜环，可荡过深渊", Vector3(3.5, 2.4, 0))
	_hint("混天绫也能缠敌：靠近敌人按 F 拉近并定身", Vector3(13.0, 2.6, 0))
	_add_swing_anchor(Vector3(6.5, 3.1, 0))
	_add_pickup(Vector3(14.0, 1.2, 0), Pickup.Kind.ENERGY)
	# B 断环深渊（18~30 空）：两个锚点，失手坠落回本段莲台
	_add_swing_anchor(Vector3(21.5, 3.6, 0))
	_add_swing_anchor(Vector3(26.5, 4.3, 0))
	_platform(30, 44, 0.4)
	_hint("荡到最高点时松手，飞得更远", Vector3(30.5, 2.4, 0))
	_add_pickup(Vector3(32.0, 1.6, 0), Pickup.Kind.ENERGY)
	# C 螺旋回廊（逐级抬高），中段有海眼引力井
	_platform(44, 50, 0.8)
	_platform(50, 56, 1.4)
	_platform(56, 62, 2.0)
	_gravity_well(Vector3(53.0, 1.4, 0), 6.5, 28.0, 1.4)
	_hint("海眼引力会把你拖向井心 —— 冲刺或摆荡脱身", Vector3(50.5, 3.6, 0))
	_add_swing_anchor(Vector3(58.0, 6.0, 0))
	# D 第一竞技场（地面 2.0）
	_platform(62, 84, 2.0)
	_add_checkpoint(Vector3(63.0, 2.0, 0))
	_spikes(72.5, 74.5, 2.0)
	_add_pickup(Vector3(70.0, 3.2, 0), Pickup.Kind.ENERGY)
	# E 海眼回廊：摆荡 + 引力井叠加，中间只有一根落柱
	_add_swing_anchor(Vector3(88.0, 6.2, 0))
	_gravity_well(Vector3(95.0, 1.0, 0), 7.5, 32.0, 0.8)
	_add_swing_anchor(Vector3(101.0, 6.4, 0))
	_platform(92, 99, 0.8)
	_add_checkpoint(Vector3(93.0, 0.8, 0))   # 海眼回廊后的中段莲台
	_add_pickup(Vector3(95.5, 2.2, 0), Pickup.Kind.ENERGY)
	# F 悬空祭坛（地面 0.6，尖刺 + 龙魂）
	_platform(104, 126, 0.6)
	_spikes(112.0, 115.0, 0.6)
	_add_swing_anchor(Vector3(108.0, 4.8, 0))
	_float_platform(118.0, 3.0, 2.6)
	_add_pickup(Vector3(118.0, 4.2, 0), Pickup.Kind.SOUL)
	_add_pickup(Vector3(122.0, 1.8, 0), Pickup.Kind.HEAL)
	# G 第二竞技场·守誓者之门（地面 0.6）
	_platform(126, 148, 0.6)
	_gravity_well(Vector3(137.0, 0.6, 0), 5.0, 24.0, 0.6)
	# H 海眼前厅（地面 0.6）
	_platform(148, 154, 0.6)
	_add_checkpoint(Vector3(149.0, 0.6, 0), false, true)
	_add_pickup(Vector3(151.0, 1.8, 0), Pickup.Kind.HEAL)
	_add_pickup(Vector3(152.2, 1.9, 0), Pickup.Kind.SOUL)
	# I 海眼 Boss 场（地面 0）：两端摆荡锚点是躲"海眼脉冲"的关键
	_platform(154, 172, 0.0)
	_add_swing_anchor(Vector3(157.5, 4.4, 0))
	_add_swing_anchor(Vector3(168.5, 4.4, 0))
	_add_pickup(Vector3(155.5, 1.2, 0), Pickup.Kind.ENERGY)
	_add_pickup(Vector3(170.5, 1.2, 0), Pickup.Kind.ENERGY)
	# 深渊两侧的隐形墙（防止 Boss 战被推出台面）
	_invisible_wall(172.4, 0.0, 14.0)
	_invisible_wall(-8.4, 0.0, 14.0)
	# 龙魂残片 1：断环深渊上空，最高点松手可吃到
	_add_pickup(Vector3(24.2, 7.2, 0), Pickup.Kind.SOUL)


func _void_edge_glow() -> void:
	## 虚空里平台靠"前缘发光条"读出轮廓：每段平台加断续的暗青符文带。
	## P0：原来每条都是整段连续亮线，glow 下变成全屏最亮的"HUD 线"；
	## 现在拆成 2~3m 小段 + 随机缺口，亮度也压到 mat_rune 的低档。
	var segs: Array = [
		[-8.0, 18.0, 0.0], [30.0, 44.0, 0.4], [44.0, 50.0, 0.8],
		[50.0, 56.0, 1.4], [56.0, 62.0, 2.0], [62.0, 84.0, 2.0],
		[92.0, 99.0, 0.8], [104.0, 126.0, 0.6], [126.0, 148.0, 0.6],
		[148.0, 154.0, 0.6], [154.0, 172.0, 0.0],
	]
	for s: Array in segs:
		var x0: float = s[0]
		var x1: float = s[1]
		var y: float = s[2]
		var xcur := x0 + 0.4
		while xcur < x1 - 0.4:
			var sw := minf(2.6 * randf_range(0.7, 1.25), x1 - 0.4 - xcur)
			if sw > 0.25 and randf() > 0.35:
				var strip := BoxMesh.new()
				strip.size = Vector3(sw, 0.02, 0.045)
				var mat := mat_rune_c if randf() > 0.4 else mat_rune_g
				Game.add_mesh(self, strip, mat,
					Vector3(xcur + sw / 2.0, y - 0.30, 2.55))
			xcur += sw + randf_range(0.3, 0.9)
		# 下沿：只保留零星的暗边，避免"悬空平台"边缘消失
		var rx := x0 + 1.0
		while rx < x1 - 1.0:
			var rw := minf(3.5, x1 - 1.0 - rx)
			var rim := BoxMesh.new()
			rim.size = Vector3(rw, 0.02, 0.03)
			Game.add_mesh(self, rim, mat_trim,
				Vector3(rx + rw / 2.0, y - 1.35, 2.45))
			rx += rw + 1.2


func _build_decor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	_build_void_depth(rng)
	await get_tree().process_frame
	# 悬浮封印石板：虚空里唯一像"建筑"的东西，但都是断裂的巨板
	var slabs: Array = [
		[-2.0, 6.5, -13.0, Vector3(10, 0.5, 6), 6.0],
		[24.0, 9.5, -24.0, Vector3(14, 0.6, 7), -8.0],
		[52.0, 7.5, -15.0, Vector3(9, 0.5, 5), 12.0],
		[78.0, 10.0, -26.0, Vector3(16, 0.7, 8), -6.0],
		[112.0, 7.0, -14.0, Vector3(11, 0.5, 6), 9.0],
		[146.0, 8.0, -18.0, Vector3(13, 0.6, 7), -11.0],
		[158.0, 10.0, -22.0, Vector3(16, 0.7, 8), 5.0],
		[166.0, 6.0, -16.0, Vector3(8, 0.5, 5), -14.0],
	]
	for s: Array in slabs:
		_decor_seal_slab(Vector3(s[0], s[1], s[2]), s[3], s[4], rng)
	await get_tree().process_frame
	# 漂浮残骸
	for i in 42:
		_decor_void_debris(Vector3(rng.randf_range(-6.0, 172.0),
			rng.randf_range(3.0, 17.0), rng.randf_range(-26.0, -6.0)), rng)
	# 记忆碎片（发光小四面体，缓慢自转）
	for i in 18:
		_decor_memory_shard(Vector3(rng.randf_range(0.0, 170.0),
			rng.randf_range(2.5, 9.0), rng.randf_range(-10.0, -3.0)), rng)
	await get_tree().process_frame
	# 平台边缘的封印结晶
	var crystals: Array = [
		[-4.0, 0.0, 1.6], [12.0, 0.0, -1.7], [31.0, 0.4, 1.8],
		[47.0, 0.8, -1.6], [59.0, 2.0, 1.7], [67.0, 2.0, -1.7],
		[96.0, 0.8, 1.8], [116.0, 0.6, -1.7], [130.0, 0.6, 1.7],
		[150.0, 0.6, -1.6], [166.0, 0.0, 1.8],
	]
	for i in crystals.size():
		var c: Array = crystals[i]
		_decor_crystal(Vector3(c[0], c[1], c[2]), i % 2 == 0, rng, false)
	# Boss 背景：海眼本体
	_decor_vortex(Vector3(164.0, 7.0, -30.0), Color(0.42, 0.22, 0.72))
	# 更远处的层层深渊之眼
	_decor_void_eye(Vector3(58.0, 6.0, -56.0), 26.0, Color(0.26, 0.16, 0.48))
	_decor_void_eye(Vector3(132.0, -2.0, -64.0), 36.0, Color(0.34, 0.16, 0.46))


func _foreground_shards() -> void:
	## 前景碎晶：贴着平台前缘、比角色更靠镜头，制造前后景层次
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var spots: Array = [
		[-5.0, 0.0], [13.5, 0.0], [33.0, 0.4], [48.0, 0.8],
		[60.5, 2.0], [80.0, 2.0], [97.0, 0.8], [110.0, 0.6],
		[131.0, 0.6], [152.0, 0.6], [161.0, 0.0],
	]
	for s: Array in spots:
		var base := Vector3(s[0], s[1], 2.35)
		for i in rng.randi_range(1, 3):
			var pr := PrismMesh.new()
			var h := rng.randf_range(0.18, 0.5)
			pr.size = Vector3(rng.randf_range(0.08, 0.18), h, 0.08)
			var mat := mat_crystal_c if rng.randf() < 0.6 else mat_crystal_p
			Game.add_mesh(self, pr, mat,
				base + Vector3(rng.randf_range(-0.35, 0.35), h * 0.5,
					rng.randf_range(-0.15, 0.2)),
				Vector3(rng.randf_range(-18, 18), rng.randf_range(0, 360),
					rng.randf_range(-18, 18)))


func _build_void_depth(rng: RandomNumberGenerator) -> void:
	## 虚空的"远景"：渐变背景 + 星尘 + 从上方垂落的光柱 + 远处的破碎巨环
	# 一层极暗的紫黑渐变幕布：避免纯黑背景与发光物形成"硬对比"
	var grad := Gradient.new()
	grad.set_color(0, Color(0.055, 0.036, 0.095))
	grad.set_color(1, Color(0.200, 0.125, 0.320))
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.width = 8
	gtex.height = 64
	gtex.fill = GradientTexture2D.FILL_LINEAR
	gtex.fill_from = Vector2(0.5, 0.0)
	gtex.fill_to = Vector2(0.5, 1.0)
	var bmat := StandardMaterial3D.new()
	bmat.albedo_texture = gtex
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.disable_receive_shadows = true
	var bquad := QuadMesh.new()
	bquad.size = Vector2(280, 130)
	var bmi := MeshInstance3D.new()
	bmi.mesh = bquad
	bmi.material_override = bmat
	bmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bmi.position = Vector3(80, 16, -55)
	add_child(bmi)

	var p := GPUParticles3D.new()
	p.amount = 240
	p.lifetime = 12.0
	p.preprocess = 12.0
	p.position = Vector3(80, 12, -18)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(95, 18, 20)
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 60.0
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.35
	pm.gravity = Vector3(0, 0.02, 0)
	pm.color = Color(0.75, 0.85, 1.0, 0.30)
	p.process_material = pm
	var dm := SphereMesh.new()
	dm.radius = 0.035
	dm.height = 0.07
	dm.radial_segments = 4
	dm.rings = 2
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.8, 0.9, 1.0, 0.55)
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.material = dmat
	p.draw_pass_1 = dm
	add_child(p)

	# 珍珠光柱：从虚空上方垂下的加法光带
	for lx in [8.0, 38.0, 72.0, 104.0, 134.0, 162.0]:
		var shaft := CylinderMesh.new()
		shaft.top_radius = 5.0
		shaft.bottom_radius = 2.2
		shaft.height = 46.0
		shaft.radial_segments = 8
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.55, 0.85, 1.0, 0.022)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		Game.add_mesh(self, shaft, mat, Vector3(lx, 32.0, -42.0))

	# 远处的破碎巨环（秩序崩解后的残构）
	for i in 3:
		var torus := TorusMesh.new()
		torus.inner_radius = 14.0 + i * 6.0
		torus.outer_radius = 14.6 + i * 6.0
		var c := Color(0.35, 0.45, 0.75).lerp(Color(0.55, 0.3, 0.75), i * 0.4)
		var mat := Game.std_mat(c, c, 0.5, 0.5)
		var mi := Game.add_mesh(self, torus, mat,
			Vector3(80.0 + i * 26.0, 4.0 - i * 6.0, -70.0),
			Vector3(80.0 + i * 12.0, i * 25.0, 6.0))
		_floaters.append({"node": mi, "speed": 0.08 + i * 0.04, "axis": "z"})


func _decor_seal_slab(pos: Vector3, size: Vector3, tilt: float,
		rng: RandomNumberGenerator) -> void:
	## 悬浮的封印石板：深色厚板 + 上下发光符文带 + 边缘碎块
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation_degrees = Vector3(rng.randf_range(-4, 4), 0, tilt)
	add_child(holder)
	var slab := BoxMesh.new()
	slab.size = size
	Game.add_mesh(holder, slab, mat_stone_dark, Vector3.ZERO)
	# 顶面与底面各一条符文带（从下方也能看见发光边）
	var strip := BoxMesh.new()
	strip.size = Vector3(size.x * 0.8, 0.03, 0.10)
	Game.add_mesh(holder, strip, mat_trim,
		Vector3(0, size.y / 2.0 + 0.02, size.z * 0.28))
	Game.add_mesh(holder, strip, mat_rune_c,
		Vector3(0, -size.y / 2.0 - 0.02, size.z * 0.28))
	# 板侧垂下的裂纹碎块
	var shard := PrismMesh.new()
	shard.size = Vector3(0.5, 1.6, 0.4)
	for i in 3:
		Game.add_mesh(holder, shard, mat_stone,
			Vector3(rng.randf_range(-size.x * 0.4, size.x * 0.4),
				-size.y / 2.0 - rng.randf_range(0.3, 0.9), 0),
			Vector3(rng.randf_range(-14, 14), rng.randf_range(0, 360), 180))
	_floaters.append({"node": holder, "speed": 0.15 + rng.randf() * 0.1,
		"axis": "y", "bob": rng.randf_range(0.2, 0.6),
		"base_y": pos.y, "phase": rng.randf() * TAU})


func _decor_void_debris(pos: Vector3, rng: RandomNumberGenerator) -> void:
	## 漂浮残骸：优先用 Poly Haven 岩石扫描件（按最长边归一化），
	## 缺文件时回落原来的随机低模碎块。浮动/自转钩子保持一致。
	var path: String = PROP_ROCKS[rng.randi() % PROP_ROCKS.size()]
	var model := _prop_sized(path, rng.randf_range(0.6, 2.2),
		rng.randf_range(0, 360), 90.0)
	if model:
		model.position = pos
		model.rotation_degrees = Vector3(rng.randf_range(-22, 22),
			rng.randf_range(0, 360), rng.randf_range(-22, 22))
		_floaters.append({"node": model, "speed": rng.randf_range(0.12, 0.35),
			"axis": "y", "bob": rng.randf_range(0.4, 1.2),
			"base_y": pos.y, "phase": rng.randf() * TAU})
		return
	## 漂浮残骸：随机低模碎块，缓慢上下浮动、自转
	var roll := rng.randf()
	var mesh: Mesh
	if roll < 0.45:
		var box := BoxMesh.new()
		box.size = Vector3(rng.randf_range(0.4, 1.8), rng.randf_range(0.15, 0.6),
			rng.randf_range(0.4, 1.4))
		mesh = box
	elif roll < 0.75:
		var pr := PrismMesh.new()
		pr.size = Vector3(rng.randf_range(0.3, 1.1), rng.randf_range(0.6, 2.0),
			rng.randf_range(0.3, 1.0))
		mesh = pr
	else:
		var sp := SphereMesh.new()
		sp.radius = rng.randf_range(0.25, 0.8)
		sp.height = sp.radius * 1.5
		sp.radial_segments = 5
		sp.rings = 4
		mesh = sp
	var mi := Game.add_mesh(self, mesh, mat_rock, pos,
		Vector3(rng.randf_range(0, 360), rng.randf_range(0, 360),
			rng.randf_range(0, 360)))
	_floaters.append({"node": mi, "speed": rng.randf_range(0.12, 0.35),
		"axis": "y", "bob": rng.randf_range(0.4, 1.2),
		"base_y": pos.y, "phase": rng.randf() * TAU})


func _decor_memory_shard(pos: Vector3, rng: RandomNumberGenerator) -> void:
	## 记忆碎片：发光的小四面体，提示"归墟在吞噬秩序"
	var pr := PrismMesh.new()
	var s := rng.randf_range(0.12, 0.28)
	pr.size = Vector3(s, s * 2.2, s)
	var mat := mat_crystal_c if rng.randf() < 0.6 else mat_crystal_p
	var mi := Game.add_mesh(self, pr, mat, pos,
		Vector3(rng.randf_range(-20, 20), rng.randf_range(0, 360),
			rng.randf_range(-20, 20)))
	_floaters.append({"node": mi, "speed": 0.7 + rng.randf() * 1.2,
		"axis": "spin_z"})


func _decor_void_eye(pos: Vector3, size: float, tint: Color) -> void:
	## 远处的深渊之眼：暗色漩涡贴片 + 两圈环
	var holder := Node3D.new()
	holder.position = pos
	add_child(holder)
	var vt := Game.tex("res://art/vortex.png")
	if vt:
		var quad := QuadMesh.new()
		quad.size = Vector2(size, size)
		var vm := ShaderMaterial.new()
		vm.shader = load("res://shaders/fx_sprite_fade.gdshader")
		vm.set_shader_parameter("tex", vt)
		vm.set_shader_parameter("tint", Color(tint.r, tint.g, tint.b, 0.55))
		vm.set_shader_parameter("fade_start", 0.30)
		vm.set_shader_parameter("fade_end", 0.52)
		vm.set_shader_parameter("strength", 0.55)
		Game.add_mesh(holder, quad, vm, Vector3.ZERO)
	for i in 2:
		var torus := TorusMesh.new()
		torus.inner_radius = size * (0.32 + i * 0.12)
		torus.outer_radius = size * (0.35 + i * 0.12)
		var mat := Game.std_mat(tint, tint * 1.3, 0.6, 0.5)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		var mi := Game.add_mesh(holder, torus, mat, Vector3.ZERO,
			Vector3(90, 0, 0))
		_floaters.append({"node": mi, "speed": 0.12 + i * 0.05, "axis": "z"})


func _build_props() -> void:
	var urns: Array = [
		[9.0, 0.0, false], [33.0, 0.4, false], [68.0, 2.0, false],
		[119.0, 0.6, true], [143.0, 0.6, false], [166.0, 0.0, false],
	]
	for u: Array in urns:
		var b := Breakable.new()
		b.drop_heal = u[2]
		b.position = Vector3(u[0], u[1], 0.8)
		add_child(b)


# ================================================================ 海眼引力井

var _wells: Array[Dictionary] = []


func _gravity_well(pos: Vector3, radius: float, strength: float, ground_y := 0.0) -> void:
	## 海眼引力井：把玩家朝井心拉（不做持续伤害，只干扰走位）
	var holder := Node3D.new()
	holder.position = pos
	add_child(holder)
	# 中心暗球
	var core := SphereMesh.new()
	core.radius = 0.55
	core.height = 1.1
	Game.add_mesh(holder, core, Game.std_mat(Color(0.02, 0.02, 0.05),
		Color(0.25, 0.12, 0.45), 0.9, 0.4), Vector3.ZERO)
	# 三圈旋转环
	for i in 3:
		var torus := TorusMesh.new()
		torus.inner_radius = 1.0 + i * 0.45
		torus.outer_radius = 1.15 + i * 0.45
		var c := Color(0.35, 0.55, 0.9).lerp(Color(0.6, 0.3, 0.9), i * 0.3)
		var mat := Game.std_mat(c, c, 1.1, 0.4)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		var mi := Game.add_mesh(holder, torus, mat, Vector3.ZERO,
			Vector3(90, 0, 0))
		_floaters.append({"node": mi, "speed": 0.6 - i * 0.12, "axis": "z"})
	# 向内流动的粒子
	var p := GPUParticles3D.new()
	p.amount = 28
	p.lifetime = 1.4
	p.position = Vector3.ZERO
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = radius * 0.8
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.2
	pm.gravity = Vector3.ZERO
	pm.radial_accel_min = -3.0
	pm.radial_accel_max = -6.0
	pm.color = Color(0.45, 0.7, 1.0, 0.55)
	p.process_material = pm
	var dm := SphereMesh.new()
	dm.radius = 0.05
	dm.height = 0.1
	dm.radial_segments = 4
	dm.rings = 2
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.5, 0.75, 1.0, 0.7)
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.material = dmat
	p.draw_pass_1 = dm
	holder.add_child(p)
	# 文字标签：明确这是"会把你拖进去"的引力井，不是装饰
	var lbl := Label3D.new()
	lbl.text = "海眼引力"
	lbl.font_size = 44
	lbl.pixel_size = 0.009
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.position = Vector3(0, 2.4, 0)
	lbl.modulate = Color(0.6, 0.9, 1.0, 0.9)
	lbl.outline_size = 9
	lbl.outline_modulate = Color(0.02, 0.05, 0.1)
	holder.add_child(lbl)
	_wells.append({"pos": pos, "radius": radius, "strength": strength})
	_add_trigger_visual_ring(holder, radius, ground_y)


func _add_trigger_visual_ring(holder: Node3D, radius: float, ground_y: float) -> void:
	## 地面上的淡青范围环，提示吸力范围
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.06
	torus.outer_radius = radius
	var mat := Game.std_mat(Color(0.35, 0.7, 0.9, 0.18),
		Color(0.3, 0.7, 0.9), 0.6, 0.4)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	Game.add_mesh(holder, torus, mat, Vector3(0, ground_y - holder.position.y + 0.05, 0),
		Vector3(90, 0, 0))


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if player == null or not is_instance_valid(player) or player.act == "dead":
		return
	for w in _wells:
		var d: Vector3 = (w["pos"] as Vector3) - player.global_position
		var dist := Vector2(d.x, d.y).length()
		if dist < 0.6 or dist > float(w["radius"]):
			continue
		var k: float = 1.0 - dist / float(w["radius"])
		var pull := Vector3(d.x, d.y * 0.6, 0).normalized() \
			* float(w["strength"]) * k * delta
		player.apply_external_force(pull)
		# 真正的"困住"：井内移动被拖慢，硬走会被吸向井心；
		# 冲刺（速度固定 17）或混天绫摆荡可以强行脱身。
		player.apply_slow(0.62 * k + 0.18, 0.1)


# ================================================================ 敌人 / Boss

func _build_encounters() -> void:
	# 第三关阵容：分潮（地面/分裂）+ 潮魇（悬浮突进）+ 渊爆水母（自爆）
	_spawn_divider(12.0, 0.0, 2.0, 16.0)
	await get_tree().process_frame
	_spawn_divider(47.0, 0.8, 44.5, 49.5)
	_spawn_divider(58.0, 2.0, 56.5, 61.5)
	await get_tree().process_frame
	# D 第一竞技场（4 敌）
	_lock_arena(82.0, 2.0, 66.0, [
		func() -> EnemyBase: return _spawn_divider(69.0, 2.0, 63.0, 81.0),
		func() -> EnemyBase: return _spawn_divider(77.0, 2.0, 63.0, 81.0),
		func() -> EnemyBase: return _spawn_wraith(71.0, 5.2, 64.0, 81.0),
		func() -> EnemyBase: return _spawn_wraith(79.0, 5.6, 64.0, 81.0),
	], "海眼结界 · 封印守卫")
	await get_tree().process_frame
	# F 段守卫：悬空祭坛上空的潮魇 + 海眼回廊的自爆水母
	_spawn_wraith(116.0, 4.0, 106.0, 124.0)
	_spawn_bomber(99.0, 4.6)
	await get_tree().process_frame
	# G 第二竞技场（4 敌）
	_lock_arena(146.0, 0.6, 130.0, [
		func() -> EnemyBase: return _spawn_divider(132.0, 0.6, 127.0, 145.0),
		func() -> EnemyBase: return _spawn_divider(140.0, 0.6, 127.0, 145.0),
		func() -> EnemyBase: return _spawn_bomber(135.0, 3.8),
		func() -> EnemyBase: return _spawn_bomber(142.0, 4.2),
	], "禁地结界 · 守誓之影")
	await get_tree().process_frame
	# I Boss「归墟海眼」
	var b := BossSeaEye.new()
	b.position = Vector3(164.0, 2.2, 0.0)
	add_child(b)
	_setup_boss(b, "归墟海眼", 154.0, 172.0, 0.0, 153.4, 155.5)
