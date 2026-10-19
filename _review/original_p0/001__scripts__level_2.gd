extends LevelBase
## 第二章 · 龙宫深狱
## ------------------------------------------------------------------
## 内容：下潜教学段（狱火喷口）→ 狱门竞技场 → 移动浮台 / 碎裂浮桥平台段
##       → 近卫狱门竞技场（更狠）→ Boss「棘狱守卫」
## 地形/装饰/遭遇战全部用 LevelBase 的积木拼装；本文件只放本章编排 + 狱火喷口机关。
## 关卡从 y=0 一路下潜到 y=-2.6（纵向落差靠层层台阶 + 深渊熔池/铁柱/垂链表现），
## water_y=-15、kill_y=-14 把台面下方拉成真正的深狱，掉下去就是坠渊。

const LEN := 174.0


class FireVent extends Node3D:
	## 狱火喷口：地面红环预警 0.7s → 焰柱喷发 0.55s（持续伤害）→ 冷却 0.45s
	const WARN_T := 0.7
	const ERUPT_T := 0.55
	const RECOVER_T := 0.45

	var period := 3.4
	var damage := 14.0
	var state := "idle"
	var t := 0.0
	var _idle_t := 1.6
	var _warn: MeshInstance3D
	var _warn_mat: StandardMaterial3D
	var _flame: Node3D
	var _light: OmniLight3D
	var _area: Area3D
	var _tick := 0.0


	func _ready() -> void:
		_build_visual()
		_idle_t = maxf(period - WARN_T - ERUPT_T - RECOVER_T, 0.6)
		# 随机相位：三处喷口不会齐喷
		t = randf() * _idle_t


	func _build_visual() -> void:
		var iron := Game.std_mat(Color(0.16, 0.12, 0.11),
			Color(0.02, 0.01, 0.01), 0.5, 0.8, 0.4)
		var hot := Game.std_mat(Color(0.45, 0.12, 0.05),
			Color(0.9, 0.25, 0.05), 1.4, 0.6)
		# 铁栅底座
		var rim := TorusMesh.new()
		rim.inner_radius = 0.62
		rim.outer_radius = 0.92
		rim.ring_segments = 20
		rim.rings = 6
		Game.add_mesh(self, rim, iron, Vector3(0, 0.05, 0),
			Vector3.ZERO, Vector3(1.0, 1.0, 1.6))
		var bar := BoxMesh.new()
		bar.size = Vector3(0.1, 0.08, 2.0)
		for i in 5:
			Game.add_mesh(self, bar, iron, Vector3(-0.54 + i * 0.27, 0.04, 0))
		# 炉膛余烬（常亮）
		var ember := CylinderMesh.new()
		ember.top_radius = 0.5
		ember.bottom_radius = 0.58
		ember.height = 0.1
		ember.radial_segments = 14
		Game.add_mesh(self, ember, hot, Vector3(0, 0.02, 0))
		# 预警环
		var ring := TorusMesh.new()
		ring.inner_radius = 0.95
		ring.outer_radius = 1.15
		ring.ring_segments = 24
		ring.rings = 6
		_warn_mat = StandardMaterial3D.new()
		_warn_mat.albedo_color = Color(1.0, 0.25, 0.1, 0.55)
		_warn_mat.emission_enabled = true
		_warn_mat.emission = Color(1.0, 0.3, 0.1)
		_warn_mat.emission_energy_multiplier = 1.6
		_warn_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_warn_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_warn_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_warn = Game.add_mesh(self, ring, _warn_mat, Vector3(0, 0.1, 0))
		_warn.visible = false
		# 焰柱（喷发时才显示）
		_flame = Node3D.new()
		_flame.position = Vector3(0, 0.1, 0)
		_flame.visible = false
		add_child(_flame)
		var flame_mat := StandardMaterial3D.new()
		flame_mat.albedo_color = Color(1.0, 0.5, 0.12, 0.72)
		flame_mat.emission_enabled = true
		flame_mat.emission = Color(1.0, 0.45, 0.08)
		flame_mat.emission_energy_multiplier = 3.2
		flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		flame_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		flame_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		var col := CylinderMesh.new()
		col.top_radius = 0.12
		col.bottom_radius = 0.62
		col.height = 3.6
		col.radial_segments = 12
		col.cap_top = false
		Game.add_mesh(_flame, col, flame_mat, Vector3(0, 1.8, 0))
		var col2 := CylinderMesh.new()
		col2.top_radius = 0.05
		col2.bottom_radius = 0.34
		col2.height = 2.4
		col2.radial_segments = 10
		col2.cap_top = false
		Game.add_mesh(_flame, col2, Game.std_mat(Color(1.0, 0.85, 0.4),
			Color(1.0, 0.8, 0.3), 4.0, 0.4), Vector3(0, 1.2, 0))
		# 火星
		var p := GPUParticles3D.new()
		p.amount = 26
		p.lifetime = 1.1
		p.position = Vector3(0, 0.3, 0)
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = 0.5
		pm.direction = Vector3(0, 1, 0)
		pm.spread = 20.0
		pm.initial_velocity_min = 2.0
		pm.initial_velocity_max = 5.0
		pm.gravity = Vector3(0, 4.0, 0)
		pm.color = Color(1.0, 0.55, 0.15, 0.8)
		p.process_material = pm
		var dm := SphereMesh.new()
		dm.radius = 0.05
		dm.height = 0.1
		dm.radial_segments = 5
		dm.rings = 3
		var dmat := StandardMaterial3D.new()
		dmat.albedo_color = Color(1.0, 0.7, 0.3, 0.9)
		dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dmat.vertex_color_use_as_albedo = true
		dmat.emission_enabled = true
		dmat.emission = Color(1.0, 0.5, 0.1)
		dmat.emission_energy_multiplier = 2.0
		dm.material = dmat
		p.draw_pass_1 = dm
		p.emitting = false
		_flame.add_child(p)
		# 火光
		_light = OmniLight3D.new()
		_light.light_color = Color(1.0, 0.45, 0.12)
		_light.light_energy = 0.5
		_light.omni_range = 5.5
		_light.light_volumetric_fog_energy = 0.2
		_light.shadow_enabled = false
		_light.position = Vector3(0, 0.6, 0)
		add_child(_light)
		# 伤害区（只打玩家：mask=2）
		_area = Area3D.new()
		_area.collision_layer = 0
		_area.collision_mask = 2
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.6, 3.6, 4.0)
		cs.shape = box
		cs.position.y = 1.8
		_area.add_child(cs)
		add_child(_area)


	func _process(delta: float) -> void:
		t += delta
		match state:
			"idle":
				if t >= _idle_t:
					state = "warn"
					t = 0.0
					_warn.visible = true
			"warn":
				var k := clampf(t / WARN_T, 0.0, 1.0)
				_warn_mat.emission_energy_multiplier = 1.6 + 5.0 * k
				var s := 1.0 + 0.2 * k
				_warn.scale = Vector3(s, 1.0, s)
				_light.light_energy = 0.5 + 1.5 * k
				if t >= WARN_T:
					_erupt()
			"erupt":
				_tick -= delta
				if _tick <= 0.0:
					_tick = 0.18
					for b in _area.get_overlapping_bodies():
						if b is Player:
							(b as Player).take_damage(damage,
								global_position.x + 0.4)
				if t >= ERUPT_T:
					_flame.visible = false
					_light.light_energy = 0.5
					state = "recover"
					t = 0.0
			"recover":
				var k2 := 1.0 - clampf(t / RECOVER_T, 0.0, 1.0)
				_warn_mat.emission_energy_multiplier = 1.4 * k2
				if t >= RECOVER_T:
					_warn.visible = false
					state = "idle"
					t = 0.0


	func _erupt() -> void:
		state = "erupt"
		t = 0.0
		_tick = 0.0
		_warn.visible = false
		_flame.visible = true
		_flame.scale = Vector3(0.65, 0.15, 0.65)
		var tw := _flame.create_tween()
		tw.tween_property(_flame, "scale", Vector3.ONE, 0.12) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_light.light_energy = 4.5
		Game.play_sfx("fire", -9.0, 1.1)
		Game.burst(get_parent(), global_position + Vector3(0, 0.4, 0),
			Color(1.0, 0.5, 0.15), 18, 5.0, 0.08, 0.5)


# ================================================================ 配置

func _configure() -> void:
	chapter_title = "第二章 · 龙宫深狱"
	chapter_id = "ch2"
	next_scene = ""                      # 每关独立：通关只结算本章
	soul_goal = 3
	kill_y = -14.0                       # 深渊底：掉下去要比第一章坠得更深
	water_y = -15.0
	spawn_wildlife = false               # 深狱里没有鲸群，只有铁与火
	# 现成素材：龙宫深狱的灯饰换成 Poly Haven 吊灯（第一章是提灯）
	lantern_style = "chandelier"
	boss_name = "棘狱守卫"
	boss_name_color = Color(1.0, 0.58, 0.24)
	summon_unit = "guard"                # 深狱 Boss 召唤的是狱卒，不是外廊的爬行者
	boss_portrait = ""                   # 新 Boss 没有专属立绘：不要借用第一章头像
	gate_color = Color(1.0, 0.42, 0.14)  # 狱火封印门：第一章的紫色和深狱配色不搭
	gate_glow = Color(1.0, 0.34, 0.08)
	boss_defeat_msg = "棘 狱 守 卫 · 已 崩 解"
	portal_msg = "深狱封印崩解 · 回响之门已开"
	# 铁灰 → 暗红 → 狱火的四段氛围：越往下越接近熔池
	zone_stops = [
		[0.0, Color(0.050, 0.058, 0.072), Color(0.24, 0.26, 0.30),
			Color(0.26, 0.29, 0.33)],
		[44.0, Color(0.070, 0.052, 0.058), Color(0.28, 0.22, 0.23),
			Color(0.35, 0.29, 0.29)],
		[86.0, Color(0.100, 0.048, 0.038), Color(0.31, 0.20, 0.18),
			Color(0.43, 0.27, 0.22)],
		[124.0, Color(0.140, 0.044, 0.028), Color(0.35, 0.17, 0.13),
			Color(0.51, 0.22, 0.15)],
		[152.0, Color(0.175, 0.040, 0.022), Color(0.39, 0.15, 0.11),
			Color(0.60, 0.21, 0.13)],
	]


# ================================================================ 材质 / 环境

func _make_materials() -> void:
	super._make_materials()
	## 龙宫深狱配色：第一章的青蓝石材 → 冷铁灰，青色描边/符文 → 狱火暗红/余烬橙
	mat_stone.albedo_color = Color(0.62, 0.50, 0.48)
	mat_stone_dark.albedo_color = Color(0.32, 0.23, 0.22)
	mat_rock.albedo_color = Color(0.20, 0.14, 0.14)
	mat_trim.albedo_color = Color(0.30, 0.12, 0.09)
	mat_trim.emission = Color(0.55, 0.14, 0.06)
	mat_trim.emission_energy_multiplier = 0.55
	mat_coral.albedo_color = Color(0.42, 0.14, 0.11)
	mat_coral.emission = Color(0.30, 0.06, 0.04)
	mat_crystal_c.albedo_color = Color(0.80, 0.42, 0.12, 0.92)
	mat_crystal_c.emission = Color(0.75, 0.32, 0.06)
	mat_crystal_p.albedo_color = Color(0.62, 0.14, 0.12, 0.92)
	mat_crystal_p.emission = Color(0.55, 0.10, 0.06)
	mat_gold.albedo_color = Color(0.62, 0.45, 0.20)
	mat_gold.emission = Color(0.40, 0.22, 0.05)
	mat_rune_c.albedo_color = Color(0.50, 0.20, 0.07)
	mat_rune_c.emission = Color(0.60, 0.22, 0.05)
	mat_rune_c.emission_energy_multiplier = 0.6
	mat_rune_g.albedo_color = Color(0.48, 0.32, 0.14)
	mat_rune_g.emission = Color(0.45, 0.24, 0.05)
	mat_kelp.albedo_color = Color(0.14, 0.08, 0.06)
	mat_kelp.emission = Color(0.07, 0.03, 0.02)


func _build_environment() -> void:
	super._build_environment()
	## 深狱环境：雾更浓更暗、体积雾自发光偏暗红（狱火映在雾里）
	_env.fog_density = 0.014
	_env.fog_sky_affect = 0.1
	_env.volumetric_fog_density = 0.026
	_env.volumetric_fog_emission = Color(0.11, 0.018, 0.006)
	_env.volumetric_fog_emission_energy = 0.45
	_env.ambient_light_energy = 0.62
	_env.glow_intensity = 0.62
	_env.glow_bloom = 0.04
	_env.adjustment_contrast = 1.08
	_env.adjustment_saturation = 1.08


func _build_water() -> void:
	super._build_water()
	## 深海面改成熔池的暗红反光，避免远处露出一条青色水线
	for c in get_children():
		var mi := c as MeshInstance3D
		if mi == null:
			continue
		var sm := mi.material_override as ShaderMaterial
		if sm and sm.shader and sm.shader.resource_path.contains("water"):
			sm.set_shader_parameter("shallow_color", Color(0.10, 0.030, 0.018))
			sm.set_shader_parameter("deep_color", Color(0.020, 0.004, 0.003))
			sm.set_shader_parameter("wave_height", 0.25)


func _process(delta: float) -> void:
	super._process(delta)
	# 深狱取景：越往下镜头越压低，露出脚下深渊。
	# 基类相机把镜头 y 钳在 2.0 以上，只能靠取景偏移把下方带进画面。
	if cam == null or player == null or boss_started:
		return
	var deep := clampf((player.global_position.x - 30.0) / 110.0, 0.0, 1.0)
	cam.set_framing(2.6 * deep, -2.4 * deep)


func _start_boss() -> void:
	## 基类负责封门/血条/激活/双目标取景；深狱 Boss 厅比第一章更低，
	## 这里再加一点下压，否则站在 -2.6 地面上的守卫会被裁在画面下缘
	if boss == null or boss_started or boss.dead:
		return
	super._start_boss()
	cam.set_framing(2.0, -1.2)


# ================================================================ 地形 + 装饰

func _build_layout() -> void:
	_build_terrain()
	await get_tree().process_frame
	await _build_decor()
	await get_tree().process_frame
	_build_props()


func _build_terrain() -> void:
	# A 起点台地 · 狱门外的锁链平台（y=0，教学段）
	_platform(-8, 18, 0.0)
	_add_checkpoint(Vector3(-4, 0, 0), true)
	_hint("狱火喷口 · 红光将亮即退开", Vector3(7.5, 2.0, 0))
	_fire_vent(13.0, 0.0, 3.6)
	_add_pickup(Vector3(16.2, 1.2, 0), Pickup.Kind.ENERGY)
	# B 碎裂阶（3 格断口，落脚低 0.4）
	_platform(21, 34, -0.4)
	_hint("异化珊瑚刺 · 不要停脚", Vector3(23.5, 1.6, 0))
	_spikes(26.5, 29.5, -0.4)
	# C 下行浮台
	_float_platform(37, -1.0, 3.0)
	_float_platform(41, -1.3, 3.0)
	# D 第一道狱门竞技场
	_platform(45, 66, -1.6)
	# E 移动浮台（断桥）
	_hint("浮台会横移 · 等它靠近再跳", Vector3(67.5, 0.4, 0))
	_moving_platform(70.3, -1.9, 2.6, 2.0, 4.6)
	_float_platform(76, -2.1, 2.8)
	# F 中段平台（检查点 + 狱火 + 龙魂）
	_platform(80, 99, -2.3)
	_add_checkpoint(Vector3(82.5, -2.3, 0))
	_float_platform(85, -0.7, 2.2)
	_add_pickup(Vector3(85, 0.6, 0), Pickup.Kind.SOUL)
	_fire_vent(91.0, -2.3, 3.2)
	_add_pickup(Vector3(95.0, -1.1, 0), Pickup.Kind.ENERGY)
	_add_pickup(Vector3(96.2, -1.2, 0), Pickup.Kind.ENERGY)
	_add_pickup(Vector3(97.4, -1.1, 0), Pickup.Kind.ENERGY)
	# G 碎裂浮桥（一路下潜）
	for i in 4:
		var fp := FallingPlatform.new()
		fp.width = 2.4
		fp.position = Vector3(101.2 + i * 3.2, -2.55 - i * 0.15, 0)
		add_child(fp)
	_add_pickup(Vector3(106.0, -1.4, 0), Pickup.Kind.SOUL)
	# H 近卫狱门竞技场（更狠：5 敌 + 尖刺 + 狱火）
	_platform(112, 134, -3.0)
	_add_pickup(Vector3(114.5, -1.9, 0), Pickup.Kind.HEAL)
	_spikes(123.5, 125.5, -3.0)
	_fire_vent(129.0, -3.0, 2.8)
	_add_pickup(Vector3(127.0, -1.9, 0), Pickup.Kind.ENERGY)
	# I 通往 Boss 厅的断台
	_float_platform(135.6, -2.9, 2.6)
	_add_pickup(Vector3(135.6, -1.6, 0), Pickup.Kind.SOUL)
	# J Boss 前厅 + 竞技场（地面 -2.6）
	_platform(138, 174, -2.6)
	_add_checkpoint(Vector3(139.2, -2.6, 0), false, true)
	_add_pickup(Vector3(142.6, -1.4, 0), Pickup.Kind.HEAL)
	_add_pickup(Vector3(144.2, -1.3, 0), Pickup.Kind.ENERGY)
	_hint("红光将亮 · 盯住地面的预警环", Vector3(141.5, -0.6, 0))
	_invisible_wall(175.0, -2.6, 14.0)
	_invisible_wall(-8.6, 0.0, 14.0)


func _build_decor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	# AI 远景全景画：龙宫废墟（深狱的暗红雾会把它压成剪影）
	var bd := Game.tex("res://art/backdrop.png")
	if bd:
		for i in 2:
			var quad := QuadMesh.new()
			quad.size = Vector2(118, 50.6)
			var m := StandardMaterial3D.new()
			m.albedo_texture = bd
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
			m.albedo_color = Color(0.78, 0.74, 0.78)
			if i == 1:
				m.uv1_scale = Vector3(-1, 1, 1)
			Game.add_mesh(self, quad, m, Vector3(28.0 + i * 117.0, 9.0, -52.0))
	# 背景铁柱阵：贯穿整个竖向画面，撑出"深井"感
	for i in 16:
		var x := -12.0 + i * 12.0 + rng.randf_range(-3.0, 3.0)
		var z := rng.randf_range(-26.0, -9.0)
		_decor_iron_column(x, z, rng.randf_range(10.0, 17.0),
			rng.randf_range(24.0, 34.0), rng)
	await get_tree().process_frame
	# 垂链：从上方垂进深渊
	for i in 12:
		var x := rng.randf_range(-10.0, 178.0)
		var z := rng.randf_range(-16.0, -6.0)
		_decor_chain(x, z, rng.randf_range(12.0, 18.0),
			rng.randf_range(10.0, 22.0))
	await get_tree().process_frame
	# 狱门 / 铁笼 / 巨环 / 熔池 / 深渊之眼
	_decor_prison_gate(163.0, -9.0)
	_decor_hanging_cage(148.0, -7.0, 8.5)
	_decor_hanging_cage(96.0, -8.0, 10.0)
	_decor_great_ring(46.0, -30.0, 8.0, mat_gold)
	_decor_great_ring(158.0, -34.0, 12.0, mat_rune_c)
	_decor_melt_sea()
	_decor_vortex(Vector3(158.0, 9.0, -26.0), Color(0.75, 0.2, 0.1))
	await get_tree().process_frame
	# 晶体（暖色，当狱火结晶读）
	var crystal_spots: Array = [
		[-5.0, 0.0, 1.6], [10.0, 0.0, -1.8], [30.0, -0.4, 1.8],
		[37.0, -1.0, -1.5], [48.0, -1.6, 1.7], [63.0, -1.6, -1.6],
		[84.0, -2.3, 1.8], [98.0, -2.3, -1.7], [121.0, -3.0, 1.7],
		[133.0, -3.0, -1.6], [146.0, -2.6, 1.8], [169.0, -2.6, -1.6],
	]
	for i in crystal_spots.size():
		var s: Array = crystal_spots[i]
		_decor_crystal(Vector3(s[0], s[1], s[2]), i % 2 == 0, rng, i % 3 == 0)
	await get_tree().process_frame
	# 海草 / 浮岩 / 狱灯 / 余烬
	for i in 26:
		var x := rng.randf_range(-8.0, 175.0)
		var z := rng.randf_range(-7.0, -3.5)
		_decor_kelp(x, z, rng)
	for i in 10:
		var x := rng.randf_range(0.0, 175.0)
		var y := rng.randf_range(6.0, 13.0)
		var z := rng.randf_range(-18.0, -6.0)
		_decor_float_rock(Vector3(x, y, z), rng)
	for x in [8.0, 42.0, 76.0, 110.0, 142.0, 166.0]:
		_decor_lantern(Vector3(x, 3.4 + sin(x) * 1.2, -4.0))
	for x in [12.0, 46.0, 92.0, 128.0, 160.0]:
		_add_embers(x, rng.randf_range(1.5, 3.0), -3.2)
	# Boss 厅地面的熔裂
	_decor_floor_cracks(154.0, 20.0)


func _build_props() -> void:
	# 渊晶瓮（可击碎，补灵力/回血）
	var urns: Array = [
		[16.5, 0.0, false], [32.5, -0.4, false], [47.0, -1.6, false],
		[61.0, -1.6, true], [83.0, -2.3, false], [96.0, -2.3, true],
		[116.0, -3.0, false], [132.0, -3.0, false], [145.0, -2.6, true],
		[170.0, -2.6, true],
	]
	for u: Array in urns:
		var b := Breakable.new()
		b.drop_heal = u[2]
		# 现成素材：深狱里的可击碎物改成 Poly Haven 木桶（第一/三章仍是青瓷瓮）
		b.style = "barrel"
		b.position = Vector3(u[0], u[1], 0.8)
		add_child(b)


# ---------------------------------------------------------------- 深狱装饰积木

func _decor_iron_column(x: float, z: float, top_y: float, h: float,
		rng: RandomNumberGenerator) -> void:
	## 贯穿画面的深渊铁柱：从上方一直插进下方的熔池雾里
	var holder := Node3D.new()
	holder.position = Vector3(x, top_y, z)
	holder.rotation_degrees = Vector3(0, 0, rng.randf_range(-3.0, 3.0))
	add_child(holder)
	var r := rng.randf_range(0.45, 0.95)
	var col := CylinderMesh.new()
	col.top_radius = r
	col.bottom_radius = r * 1.25
	col.height = h
	col.radial_segments = 10
	Game.add_mesh(holder, col, mat_stone_dark, Vector3(0, -h * 0.5, 0))
	# 横向铁箍
	var band := CylinderMesh.new()
	band.top_radius = r * 1.35
	band.bottom_radius = r * 1.35
	band.height = 0.45
	band.radial_segments = 10
	for i in 3:
		Game.add_mesh(holder, band, mat_rock,
			Vector3(0, -h * (0.25 + i * 0.22), 0))
	# 柱脚底部的狱火微光
	var glow := Game.std_mat(Color(0.4, 0.1, 0.03),
		Color(1.0, 0.28, 0.06), 1.4, 0.5)
	var ring := TorusMesh.new()
	ring.inner_radius = r * 1.3
	ring.outer_radius = r * 1.7
	ring.ring_segments = 18
	ring.rings = 5
	Game.add_mesh(holder, ring, glow, Vector3(0, -h * 0.94, 0))


func _decor_chain(x: float, z: float, top_y: float, length: float) -> void:
	## 垂链：一根主缆 + 三个链环，垂进深渊
	var holder := Node3D.new()
	holder.position = Vector3(x, top_y, z)
	add_child(holder)
	var main := CylinderMesh.new()
	main.top_radius = 0.09
	main.bottom_radius = 0.06
	main.height = length
	main.radial_segments = 6
	Game.add_mesh(holder, main, mat_gold, Vector3(0, -length * 0.5, 0))
	var link := TorusMesh.new()
	link.inner_radius = 0.16
	link.outer_radius = 0.26
	link.ring_segments = 14
	link.rings = 5
	for i in 3:
		Game.add_mesh(holder, link, mat_gold,
			Vector3(0, -length * (0.2 + i * 0.22), 0),
			Vector3(90, 0, 90 * (i % 2)))
	var hook := SphereMesh.new()
	hook.radius = 0.22
	hook.height = 0.44
	Game.add_mesh(holder, hook, mat_rock, Vector3(0, -length, 0))


func _decor_hanging_cage(x: float, z: float, y: float) -> void:
	## 悬挂铁笼（龙宫深狱的处刑笼）
	var holder := Node3D.new()
	holder.position = Vector3(x, y, z)
	add_child(holder)
	var bar := BoxMesh.new()
	bar.size = Vector3(0.11, 3.2, 0.11)
	for i in 8:
		var a := TAU * i / 8.0
		Game.add_mesh(holder, bar, mat_rock,
			Vector3(cos(a) * 0.85, 0, sin(a) * 0.85))
	var rim := TorusMesh.new()
	rim.inner_radius = 0.82
	rim.outer_radius = 0.98
	rim.ring_segments = 16
	rim.rings = 5
	for yy in [1.55, -1.55]:
		Game.add_mesh(holder, rim, mat_rock, Vector3(0, yy, 0))
	var rope := CylinderMesh.new()
	rope.top_radius = 0.07
	rope.bottom_radius = 0.07
	rope.height = 6.0
	rope.radial_segments = 6
	Game.add_mesh(holder, rope, mat_gold, Vector3(0, 4.6, 0))


func _decor_prison_gate(x: float, z: float) -> void:
	## Boss 身后的狱门：巨柱 + 门楣 + 铁栅 + 熔火封印环
	var holder := Node3D.new()
	holder.position = Vector3(x, 0, z)
	add_child(holder)
	var pillar := BoxMesh.new()
	pillar.size = Vector3(2.2, 22.0, 2.2)
	Game.add_mesh(holder, pillar, mat_stone_dark, Vector3(-5.2, 6.0, 0))
	Game.add_mesh(holder, pillar, mat_stone_dark, Vector3(5.2, 6.0, 0))
	var lintel := BoxMesh.new()
	lintel.size = Vector3(12.6, 2.4, 2.4)
	Game.add_mesh(holder, lintel, mat_stone_dark, Vector3(0, 16.0, 0))
	# 铁栅
	var bar := BoxMesh.new()
	bar.size = Vector3(0.32, 14.0, 0.5)
	for i in 11:
		Game.add_mesh(holder, bar, mat_rock, Vector3(-5.0 + i * 1.0, 7.0, 0.9))
	var cross := BoxMesh.new()
	cross.size = Vector3(10.5, 0.32, 0.5)
	Game.add_mesh(holder, cross, mat_rock, Vector3(0, 9.6, 0.92))
	Game.add_mesh(holder, cross, mat_rock, Vector3(0, 4.2, 0.92))
	# 熔火封印环
	var ring := TorusMesh.new()
	ring.inner_radius = 3.2
	ring.outer_radius = 3.6
	ring.ring_segments = 28
	ring.rings = 8
	var rmat := Game.std_mat(Color(0.5, 0.12, 0.05),
		Color(1.0, 0.3, 0.08), 1.8, 0.4)
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mi := Game.add_mesh(holder, ring, rmat, Vector3(0, 8.2, 1.2),
		Vector3(90, 0, 0))
	_floaters.append({"node": mi, "speed": 0.25, "axis": "z"})


func _decor_melt_sea() -> void:
	## 深渊底部的狱火熔池：从台面断口望下去能看到下方翻涌的暗红熔岩
	var plane := PlaneMesh.new()
	plane.size = Vector2(430, 62)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.22, 0.035, 0.015)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.24, 0.06)
	m.emission_energy_multiplier = 0.85
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.disable_receive_shadows = true
	Game.add_mesh(self, plane, m, Vector3(82.0, -13.2, -24.0))
	# 几道更亮的熔流
	for i in 5:
		var strip := BoxMesh.new()
		strip.size = Vector3(34.0, 0.05, 0.8)
		var sm := Game.std_mat(Color(0.9, 0.35, 0.1),
			Color(1.0, 0.4, 0.1), 2.0, 0.4)
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		Game.add_mesh(self, strip, sm,
			Vector3(10.0 + i * 34.0, -13.1, -24.0),
			Vector3(0, randf_range(-8.0, 8.0), 0))


func _decor_floor_cracks(x: float, w: float) -> void:
	## Boss 厅地面上的熔裂（贴地发光细条）
	var mat := Game.std_mat(Color(0.9, 0.32, 0.08),
		Color(1.0, 0.35, 0.08), 2.2, 0.4)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for i in 6:
		var crack := BoxMesh.new()
		crack.size = Vector3(randf_range(1.6, 3.4), 0.03, 0.12)
		Game.add_mesh(self, crack, mat,
			Vector3(x - w * 0.5 + w * (i + 0.5) / 6.0 + randf_range(-1.0, 1.0),
				-2.585, randf_range(-1.6, 1.6)),
			Vector3(0, randf_range(-25.0, 25.0), 0))


func _add_embers(x: float, y: float, z: float, count := 24) -> void:
	## 狱火余烬：从下往上缓缓飘的暗红火星
	var p := GPUParticles3D.new()
	p.amount = count
	p.lifetime = 4.5
	p.preprocess = 2.0
	p.position = Vector3(x, y, z)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(7.0, 1.2, 2.0)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 28.0
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 1.3
	pm.gravity = Vector3(0, 0.4, 0)
	pm.color = Color(1.0, 0.45, 0.12, 0.5)
	p.process_material = pm
	var dm := SphereMesh.new()
	dm.radius = 0.035
	dm.height = 0.07
	dm.radial_segments = 4
	dm.rings = 2
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(1.0, 0.55, 0.2, 0.65)
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dmat.vertex_color_use_as_albedo = true
	dm.material = dmat
	p.draw_pass_1 = dm
	add_child(p)


# ---------------------------------------------------------------- 狱火喷口

func _fire_vent(x: float, ytop: float, period := 3.4) -> void:
	var v := FireVent.new()
	v.period = period
	v.position = Vector3(x, ytop, 0)
	add_child(v)


# ================================================================ 敌人 / 竞技场 / Boss

func _build_encounters() -> void:
	_spawn_guard(30.0, -0.4, 22.0, 33.0)
	await get_tree().process_frame
	# D 第一道狱门：清怪开门
	_lock_arena(64.5, -1.6, 48.0, [
		func() -> EnemyBase: return _spawn_guard(51.0, -1.6, 46.5, 63.0),
		func() -> EnemyBase: return _spawn_guard(57.0, -1.6, 46.5, 63.0),
		func() -> EnemyBase: return _spawn_shooter(54.0, 0.2, 46.5, 63.5),
	], "狱门结界 · 斩尽狱卒")
	await get_tree().process_frame
	# E 移动浮台旁的浮游炮
	_spawn_shooter(96.5, -0.3, 82.0, 98.5)
	await get_tree().process_frame
	# 新怪：狱门旁的囚晶（固定炮台，深狱专属阵容：狱卒 / 浮母 / 囚晶）
	# 囚晶原点=晶体核心，必须离地 ≤1.5m 才能被站地普攻打到
	_spawn_turret(86.0, -0.9)
	_spawn_turret(131.0, -1.8)
	await get_tree().process_frame
	# F 中段平台
	_spawn_guard(94.0, -2.3, 90.5, 98.0)
	await get_tree().process_frame
	# H 近卫狱门：更狠（4 敌 + 尖刺 + 狱火；狱卒血厚，别再堆 5 个）
	_lock_arena(133.0, -3.0, 116.0, [
		func() -> EnemyBase: return _spawn_guard(118.0, -3.0, 113.0, 132.0),
		func() -> EnemyBase: return _spawn_guard(130.0, -3.0, 113.0, 132.0),
		func() -> EnemyBase: return _spawn_shooter(120.0, -1.1, 113.0, 133.0),
		func() -> EnemyBase: return _spawn_shooter(127.5, -1.0, 113.0, 133.0),
	], "狱门结界 · 近卫苏醒")
	await get_tree().process_frame
	# J Boss「棘狱守卫」
	var b := BossWarden.new()
	b.arena_min_x = 142.0
	b.arena_max_x = 173.0
	b.ground_y = -2.6
	b.position = Vector3(160.0, -2.6, 0)
	add_child(b)
	_setup_boss(b, "棘狱守卫", 142.0, 173.0, -2.6, 141.0, 146.0)
