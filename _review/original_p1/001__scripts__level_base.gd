class_name LevelBase
extends Node3D
## 关卡基类：环境 / 地形积木 / 装饰 / 检查点 / 封印门 / 敌人 / Boss 流程 / 生死循环
## ------------------------------------------------------------------
## 章节脚本（level_1.gd / level_2.gd）只需要：
##   _configure()        设置标题、配色、Boss 名字、下一关
##   _build_layout()     用本类的积木搭地形与装饰（可 await 分帧）
##   _build_encounters() 摆敌人 / 竞技场 / Boss（可 await 分帧）
## 本类负责：黑屏分帧加载、相机、HUD、检查点、复活、Boss 战落地流程、氛围渐变。
## ------------------------------------------------------------------

var chapter_title := ""
var chapter_hint := ""
var chapter_id := ""             # "ch1" / "ch2"：用于记录通关进度
var next_scene := ""            # 通关传送门去向；空 = 直接弹胜利结算（每关独立）
var soul_goal := 3              # 本章龙魂残片总数（HUD 用）
var kill_y := -6.5
var water_y := -7.0
var spawn_wildlife := false     # 是否放巨鲸/鱼群（第一章的开阔海渊用）
var zone_stops: Array = []      # [x, 雾色, 环境光色, 体积雾反照率]
var boss_name := "归墟之喉 · 渊狱兽"
var boss_name_color := Color(0.85, 0.5, 1.0)
var gate_color := Color(0.55, 0.30, 0.90)      # 封印门主色（章节可覆盖）
var gate_glow := Color(0.55, 0.30, 0.95)       # 封印门发光/碎裂粒子色
var boss_portrait := "res://art/portrait_boss.png"
var boss_defeat_msg := "渊 兽 已 被 镇 压"
var summon_unit := "crawler"    # Boss 召唤的小怪类型（章节可覆盖：guard / wraith）
var portal_msg := "秩序回响之门已开启"
var boss_gate_x := 0.0
var boss_trigger_x := 0.0
var arena_min_x := 0.0
var arena_max_x := 0.0
var arena_ground_y := 0.0

var player: Player
var cam: PlayerCamera
var hud: HUD
var checkpoint_pos := Vector3(0, 0.6, 0)
var boss: EnemyBase
var boss_gate: Node3D = null
var boss_trigger: Area3D = null
var _boss_summons: Array = []      # Boss 召唤出来的小怪（Boss 死亡/重置时一并清场）
var boss_started := false
var build_done := false

var _floaters: Array[Dictionary] = []
var _checkpoints: Array[Dictionary] = []
var _arenas: Array[Dictionary] = []
var _arena_poll_t := 0.0
var _t := 0.0
var _env: Environment
var _sun: DirectionalLight3D
var _whale: Node3D
var _whale_tail: Node3D
var _whale_seed := 0.0
var _fish: Array[MeshInstance3D] = []

# 共享材质（子类可直接用，也可在 _make_materials 后覆盖参数）
var mat_stone: StandardMaterial3D
var mat_stone_dark: StandardMaterial3D
var mat_trim: StandardMaterial3D
var mat_coral: StandardMaterial3D
var mat_crystal_c: StandardMaterial3D
var mat_crystal_p: StandardMaterial3D
var mat_gold: StandardMaterial3D
var mat_rune_c: StandardMaterial3D
var mat_rune_g: StandardMaterial3D
var mat_kelp: StandardMaterial3D
var mat_rock: StandardMaterial3D


# ================================================================ 生命周期

func _ready() -> void:
	_configure()
	Game.start_ambient()
	Game.play_theme(false)
	Game.run_active = true
	Game.souls = 0
	Game.show_loading(chapter_title, "正在打捞龙宫的残骸……")

	_make_materials()
	_build_environment()
	_build_water()
	_build_player_and_camera()
	_build_hud()
	await get_tree().process_frame
	await _build_layout()
	await get_tree().process_frame
	await _build_encounters()
	# 有些莲台落在了封印门/竞技场里面：先藏起来，清完怪再出现（否则可以来回踩莲台无限回血）
	_gate_checkpoints_in_arenas()
	if spawn_wildlife:
		_build_whale()
		_build_fish_school()

	# P0 灯光卫生：兜底扫描整关的小灯（敌人/Boss 在各自脚本里也会显式调 Game.tune_light）
	_tune_level_lights(self)

	Game.set_loading_hint("正在预热特效……")
	Game.prewarm_fx(self)
	await get_tree().process_frame
	await get_tree().process_frame
	build_done = true
	Game.scene_ready()
	if chapter_title != "":
		hud.show_message(chapter_title, 2.8, 60)


func _configure() -> void:
	pass  # 子类设置标题/配色/Boss 文案


func _build_layout() -> void:
	pass  # 子类搭地形与装饰


func _build_encounters() -> void:
	pass  # 子类摆敌人 / 竞技场 / Boss


# ================================================================ 材质

func _make_materials() -> void:
	mat_stone = Game.std_mat(Color(0.16, 0.24, 0.3), Color(0.01, 0.03, 0.04),
		0.4, 0.85)
	mat_stone_dark = Game.std_mat(Color(0.09, 0.13, 0.18),
		Color(0.005, 0.015, 0.02), 0.3, 0.9)
	# 平台描边：原来 emission 1.3 + 宽度 0.08，过曝成一条贯穿全屏的青色激光线
	# P0：再降一档，并配合 _platform 里的分段（只留"石缝里透出的微光"）
	mat_trim = Game.std_mat(Color(0.14, 0.34, 0.36), Color(0.07, 0.20, 0.22),
		0.35, 0.5)
	mat_coral = Game.std_mat(Color(0.7, 0.3, 0.4), Color(0.5, 0.15, 0.25),
		0.5, 0.6)
	# 晶体：带一点透明与低自发光，避免"平色纸片"
	mat_crystal_c = Game.std_mat(Color(0.22, 0.62, 0.66, 0.92),
		Color(0.16, 0.6, 0.62), 0.8, 0.25)
	mat_crystal_c.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_crystal_c.rim_enabled = true
	mat_crystal_c.rim = 0.5
	mat_crystal_p = Game.std_mat(Color(0.46, 0.3, 0.68, 0.92),
		Color(0.42, 0.2, 0.62), 0.8, 0.25)
	mat_crystal_p.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_crystal_p.rim_enabled = true
	mat_crystal_p.rim = 0.5
	mat_gold = Game.std_mat(Color(0.85, 0.68, 0.3), Color(0.6, 0.4, 0.1),
		0.6, 0.35, 0.85)
	mat_rune_c = Game.std_mat(Color(0.2, 0.45, 0.5), Color(0.15, 0.5, 0.5),
		0.3, 0.6)
	mat_rune_g = Game.std_mat(Color(0.5, 0.4, 0.2), Color(0.55, 0.38, 0.12),
		0.3, 0.6)
	mat_kelp = Game.std_mat(Color(0.1, 0.35, 0.3), Color(0.05, 0.25, 0.2),
		0.2, 0.7)
	mat_rock = Game.std_mat(Color(0.1, 0.15, 0.2), Color(0.01, 0.03, 0.04),
		0.25, 0.9)
	mat_rock.metallic = 0.0        # 原来 metallic 0.9 + 无反射源 = 纯黑椭圆
	mat_rock.roughness = 0.85
	# AI 石材纹理（三向贴图，世界坐标平铺）
	var stone_tex := Game.tex("res://art/stone.png")
	if stone_tex:
		var stone_nrm := _detail_normal(5.0, 0.55)
		for m: StandardMaterial3D in [mat_stone, mat_stone_dark, mat_rock]:
			m.albedo_texture = stone_tex
			m.uv1_triplanar = true
			m.uv1_scale = Vector3(0.13, 0.13, 0.13)
			# P0：平涂石材加程序化 normal（零新资产），远近都有"表面"
			m.normal_enabled = true
			m.normal_texture = stone_nrm
			m.normal_scale = 0.6
			m.roughness_texture = stone_nrm
			m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		mat_stone.albedo_color = Color(0.75, 0.88, 0.95)
		mat_stone_dark.albedo_color = Color(0.38, 0.48, 0.58)


func _detail_normal(freq := 5.0, strength := 0.55) -> NoiseTexture2D:
	## 程序化石材细节法线：FastNoiseLite → 法线图，零资产成本
	var fn := FastNoiseLite.new()
	fn.frequency = freq
	fn.fractal_octaves = 4
	var n := NoiseTexture2D.new()
	n.noise = fn
	n.seamless = true
	n.as_normal_map = true
	n.bump_strength = strength
	n.width = 512
	n.height = 512
	return n


# ================================================================ 环境

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky.gdshader")
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.16, 0.28, 0.34)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	# 原值 glow_hdr_threshold 0.9 会把 2% 像素裁到纯白，描边全部过曝
	# P0：按 level 整形 + 提阈值，只让 10% 的点缀发光，不再全屏泛白
	env.glow_intensity = 0.5
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.45
	env.glow_hdr_luminance_cap = 8.0
	env.set("glow_levels/1", 0.8)
	env.set("glow_levels/2", 1.0)
	env.set("glow_levels/3", 0.4)
	env.set("glow_levels/4", 0.1)
	env.set("glow_levels/5", 0.0)
	env.set("glow_levels/6", 0.0)
	env.set("glow_levels/7", 0.0)
	env.fog_enabled = true
	env.fog_light_color = Color(0.018, 0.062, 0.085)
	# P0：深度雾 + 高度雾 + 空气透视，让远景真的"退"
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_begin = 6.0
	env.fog_depth_end = 110.0
	env.fog_depth_curve = 1.5
	env.fog_height = 8.0
	env.fog_height_density = 0.06
	env.fog_aerial_perspective = 0.30
	env.fog_sky_affect = 0.20
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.010
	env.volumetric_fog_albedo = Color(0.3, 0.6, 0.65)
	env.volumetric_fog_emission = Color(0.01, 0.04, 0.05)
	env.volumetric_fog_emission_energy = 0.3
	env.volumetric_fog_anisotropy = 0.55
	env.volumetric_fog_length = 90.0
	env.volumetric_fog_ambient_inject = 0.4
	env.ssao_enabled = false  # 实测 +3.4ms，这种画风收益极低
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.10
	env.adjustment_saturation = 1.04
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	_env = env

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(0.75, 0.95, 1.0)
	sun.light_energy = 1.35
	sun.light_volumetric_fog_energy = 1.4
	sun.shadow_enabled = true
	# 4 级 PSSM 会把整关重画 4 遍：改成单级正交 + 近裁剪，只保留近处角色投影
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 30.0
	sun.shadow_bias = 0.06
	sun.shadow_normal_bias = 1.5
	sun.rotation_degrees = Vector3(-52, 34, 0)
	add_child(sun)
	_sun = sun

	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.25, 0.45, 0.75)
	fill.light_energy = 0.35
	fill.rotation_degrees = Vector3(-20, -140, 0)
	add_child(fill)


func _tune_level_lights(root: Node) -> void:
	## P0 灯光卫生：小灯不注入体积雾、收紧范围/衰减、远处淡出。
	## "整屏紫色/洋红洗地"的根因：每只怪自带 OmniLight，VFE 默认 1.0，
	## 几十盏小灯逐 froxel 往体积雾里注入颜色，把场景照成一片同色。
	for n in root.find_children("*", "Light3D", true, false):
		var l := n as Light3D
		if l == null or l is DirectionalLight3D or l.has_meta("light_tuned"):
			continue
		if l.light_energy <= 2.0:
			l.light_energy = minf(l.light_energy, 0.45)
			l.light_volumetric_fog_energy = 0.0
			if l is OmniLight3D:
				var om := l as OmniLight3D
				om.omni_range = minf(om.omni_range, 3.8)
				om.omni_attenuation = 1.6
			l.distance_fade_enabled = true
			l.distance_fade_begin = 12.0
			l.distance_fade_length = 6.0
		else:
			# Boss 主灯不进"洗雾"区，只保留有限体积光
			l.light_volumetric_fog_energy = minf(l.light_volumetric_fog_energy, 0.3)


func _build_water() -> void:
	if zone_stops.is_empty():
		zone_stops = [[0.0, Color(0.05, 0.16, 0.2), Color(0.25, 0.4, 0.45),
			Color(0.3, 0.6, 0.65)]]
	var plane := PlaneMesh.new()
	plane.size = Vector2(700, 140)
	# 原 160×32 细分 = 10240 三角形，一个人占主 pass 10%
	plane.subdivide_width = 96
	plane.subdivide_depth = 16
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/water.gdshader")
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(80, water_y, -20)
	add_child(mi)


# ================================================================ 玩家 / 相机 / HUD

func _build_player_and_camera() -> void:
	player = Player.new()
	player.position = Vector3(0, 0.6, 0)
	add_child(player)
	player.died.connect(_on_player_died)

	cam = PlayerCamera.new()
	cam.target = player
	add_child(cam)
	cam.current = true
	cam.snap_to_target()

	# 周围漂浮的灵尘（数量从 70 降到 40，雾里看不出差别）
	for cx in [25.0, 80.0, 145.0]:
		var p := GPUParticles3D.new()
		p.amount = 40
		p.lifetime = 8.0
		p.preprocess = 8.0
		p.position = Vector3(cx, 4.0, 0)
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(18, 7, 6)
		pm.direction = Vector3(0, 1, 0)
		pm.spread = 180.0
		pm.initial_velocity_min = 0.1
		pm.initial_velocity_max = 0.4
		pm.gravity = Vector3(0, 0.05, 0)
		pm.color = Color(0.4, 0.8, 0.8, 0.22)
		p.process_material = pm
		var dm := SphereMesh.new()
		dm.radius = 0.025
		dm.height = 0.05
		dm.radial_segments = 4
		dm.rings = 2
		var dmat := StandardMaterial3D.new()
		dmat.albedo_color = Color(0.5, 0.9, 0.9, 0.5)
		dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dm.material = dmat
		p.draw_pass_1 = dm
		add_child(p)


func _build_hud() -> void:
	hud = HUD.new()
	add_child(hud)
	hud.set_soul_total(soul_goal)
	hud.bind_player(player)
	hud.respawn_callback = _respawn_full
	hud.restart_callback = func() -> void:
		# 哪一关就重开哪一关；闯关模式下保住当前章节与已解锁技能，
		# 死亡重开只会回到"当前这一关"，不会退回第一关。
		if Game.campaign:
			Game.campaign_chapter = chapter_id
		Game.start_run()
		Game.change_scene(scene_file_path)
	# 闯关模式：本章场景即当前章节；监听"集满龙魂解锁技能"
	if Game.campaign:
		Game.campaign_chapter = chapter_id
	if Game.has_signal("skill_unlocked"):
		Game.skill_unlocked.connect(_on_skill_unlocked)


func _on_skill_unlocked(id: String, title: String) -> void:
	if hud == null:
		return
	var key := Game.skill_key(id)
	hud.show_message("龙魂共鸣 · 解锁技能「%s」（%s 键）" % [title, key], 3.0, 42)
	Game.play_sfx("orb", 0.0, 0.85)
	Game.burst(self, player.global_position + Vector3(0, 1.2, 0),
		Color(0.55, 1.0, 0.8), 36, 7.0, 0.1, 0.9)


# ================================================================ 地形积木

func _platform(x0: float, x1: float, ytop: float, deep := 1.6,
		dark := false) -> StaticBody3D:
	## 主站台。deep 从 9 减到 1.6：镜头里不再是一大块占满下半屏的深色前脸，
	## 平台下沿能看到水面与雾，画面从"石墙"变成"悬空石台"。
	var w := x1 - x0
	var cx := (x0 + x1) / 2.0
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = Vector3(cx, ytop - deep / 2.0, 0)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(w, deep, 5.0)
	col.shape = shape
	body.add_child(col)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(w, deep, 5.0)
	Game.add_mesh(body, mesh, mat_stone_dark if dark else mat_stone,
		Vector3.ZERO)
	# 顶面亮边（朝镜头）：P0 改为分段、断续的"石缝光"
	# 原来整条 w 长的亮线在 glow 下变成贯穿全屏的激光线，比角色还抢眼
	var xcur := -w / 2.0 + 0.3
	while xcur < w / 2.0 - 0.3:
		var seg_w := minf(2.8 * randf_range(0.75, 1.2),
			w / 2.0 - 0.3 - xcur)
		if seg_w > 0.3 and randf() > 0.32:
			var trim := BoxMesh.new()
			trim.size = Vector3(seg_w, 0.02, 0.05)
			Game.add_mesh(body, trim, mat_trim,
				Vector3(xcur + seg_w / 2.0, deep / 2.0 - 0.005, 2.5))
		xcur += seg_w + randf_range(0.25, 0.7)
	# 顶面散落的发光符文砖
	var tile := BoxMesh.new()
	tile.size = Vector3(0.75, 0.045, 0.75)
	for i in maxi(int(w / 7.0), 1):
		var tmat := mat_rune_c if randf() < 0.65 else mat_rune_g
		Game.add_mesh(body, tile, tmat,
			Vector3(randf_range(-w / 2.0 + 1.0, w / 2.0 - 1.0),
				deep / 2.0 + 0.01, randf_range(-1.8, 1.8)),
			Vector3(0, randf_range(0, 90), 0))
	add_child(body)
	return body


func _float_platform(x: float, ytop: float, w := 3.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = Vector3(x, ytop - 0.4, 0)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(w, 0.8, 4.2)
	col.shape = shape
	body.add_child(col)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(w, 0.8, 4.2)
	Game.add_mesh(body, mesh, mat_stone, Vector3.ZERO)
	var trim := BoxMesh.new()
	trim.size = Vector3(w, 0.03, 0.05)
	Game.add_mesh(body, trim, mat_trim, Vector3(0, 0.38, 2.1))
	# 底部垂石
	var tip := CylinderMesh.new()
	tip.top_radius = w * 0.32
	tip.bottom_radius = 0.05
	tip.height = 1.2
	Game.add_mesh(body, tip, mat_stone_dark, Vector3(0, -1.0, 0))
	add_child(body)
	return body


func _moving_platform(x: float, ytop: float, w := 2.6,
		travel := 3.0, period := 4.0) -> AnimatableBody3D:
	## 巡逻浮台（第二章机制）：横向往返，玩家站上去会被带走
	var body := AnimatableBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.sync_to_physics = false
	body.position = Vector3(x, ytop - 0.35, 0)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(w, 0.7, 4.0)
	col.shape = shape
	body.add_child(col)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(w, 0.7, 4.0)
	Game.add_mesh(body, mesh, mat_stone, Vector3.ZERO)
	var trim := BoxMesh.new()
	trim.size = Vector3(w, 0.03, 0.05)
	var trim_mat := Game.std_mat(Color(0.5, 0.85, 0.75),
		Color(0.4, 0.9, 0.75), 0.8, 0.4)
	Game.add_mesh(body, trim, trim_mat, Vector3(0, 0.33, 2.0))
	# 两侧锁链
	var chain := CylinderMesh.new()
	chain.top_radius = 0.04
	chain.bottom_radius = 0.04
	chain.height = 1.6
	for side in [-1.0, 1.0]:
		Game.add_mesh(body, chain, mat_gold,
			Vector3(side * w * 0.38, 0.7, 0))
	add_child(body)
	_floaters.append({"node": body, "speed": period, "axis": "patrol",
		"base_x": x, "travel": travel})
	return body


func _invisible_wall(x: float, ybase: float, h: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = Vector3(x, ybase + h / 2.0, 0)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.0, h, 6.0)
	col.shape = shape
	body.add_child(col)
	add_child(body)


func _spikes(x0: float, x1: float, ytop: float) -> void:
	## 异化珊瑚刺：持续站立会受伤
	var cx := (x0 + x1) / 2.0
	var w := x1 - x0
	var holder := Node3D.new()
	holder.position = Vector3(cx, ytop, 0)
	add_child(holder)
	var spike := CylinderMesh.new()
	spike.top_radius = 0.0
	spike.bottom_radius = 0.13
	spike.height = 0.85
	var n := int(w / 0.45)
	for i in n:
		for zrow in 3:
			Game.add_mesh(holder, spike, mat_coral,
				Vector3(-w / 2.0 + 0.3 + i * 0.45 + randf_range(-0.08, 0.08),
					0.3 + randf_range(-0.06, 0.06),
					-1.2 + zrow * 1.2 + randf_range(-0.2, 0.2)),
				Vector3(randf_range(-12, 12), 0, randf_range(-12, 12)))
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(w, 1.2, 5.0)
	cs.shape = box
	cs.position.y = 0.5
	area.add_child(cs)
	holder.add_child(area)
	var timer := Timer.new()
	timer.wait_time = 0.35
	timer.autostart = true
	holder.add_child(timer)
	timer.timeout.connect(func() -> void:
		for b in area.get_overlapping_bodies():
			if b is Player:
				(b as Player).take_damage(12.0, b.global_position.x + 0.3))


# ================================================================ 互动物件

func _add_pickup(pos: Vector3, kind: Pickup.Kind) -> void:
	var p := Pickup.new()
	p.kind = kind
	p.position = pos
	add_child(p)


func _add_swing_anchor(pos: Vector3, radius := 0.55) -> SwingAnchor:
	## 混天绫摆荡锚点（龙宫铜环）；玩家用 F 抓取
	var a := SwingAnchor.new()
	a.radius = radius
	a.position = pos
	add_child(a)
	return a


func _hint(text: String, pos: Vector3) -> void:
	## 教学提示：放到角色前方（z=+1.4）并关闭深度测试，避免被角色/敌人挡住；
	## 字号与抬高压低，避开 HUD 中央讯息的屏幕 30% 高度带
	var lbl := Label3D.new()
	lbl.text = text
	lbl.font = Game.world_font
	lbl.font_size = 26
	lbl.outline_size = 7
	lbl.outline_modulate = Color(0, 0.05, 0.08, 0.8)
	lbl.modulate = Color(0.72, 0.93, 0.93, 0.9)
	lbl.pixel_size = 0.0085
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.position = pos + Vector3(0, 0.9, 1.4)
	add_child(lbl)


func _add_checkpoint(ground_pos: Vector3, start_active := false,
		is_boss_cp := false) -> void:
	var holder := Node3D.new()
	holder.position = ground_pos
	add_child(holder)
	# 莲台
	var base := CylinderMesh.new()
	base.top_radius = 0.9
	base.bottom_radius = 1.1
	base.height = 0.3
	Game.add_mesh(holder, base, mat_gold, Vector3(0, 0.15, 0))
	var petal := SphereMesh.new()
	petal.radius = 0.32
	petal.height = 0.64
	var petal_mat := Game.std_mat(Color(0.92, 0.5, 0.65),
		Color(0.7, 0.25, 0.4), 0.35, 0.55)
	for i in 8:
		var a := TAU * i / 8.0
		Game.add_mesh(holder, petal, petal_mat,
			Vector3(cos(a) * 0.62, 0.36, sin(a) * 0.62),
			Vector3(0, -rad_to_deg(a), 24), Vector3(1.5, 0.45, 0.9))
	var core := SphereMesh.new()
	core.radius = 0.2
	core.height = 0.4
	var core_mat := Game.std_mat(Color(0.6, 1.0, 0.8), Color(0.4, 0.95, 0.7),
		0.6, 0.4)
	Game.add_mesh(holder, core, core_mat, Vector3(0, 0.45, 0))
	var light := OmniLight3D.new()
	light.light_color = Color(0.5, 1.0, 0.75)
	light.light_energy = 0.4
	light.omni_range = 5.0
	light.light_volumetric_fog_energy = 0.15
	light.position = Vector3(0, 1.2, 0)
	light.shadow_enabled = false
	holder.add_child(light)
	Game.tune_light(light, 0.35, 4.0, 0.05)

	# 升天光柱（叠加混合，激活后增亮）
	var beam := CylinderMesh.new()
	beam.top_radius = 0.5
	beam.bottom_radius = 0.85
	beam.height = 5.5
	var beam_mat := StandardMaterial3D.new()
	beam_mat.albedo_color = Color(0.5, 1.0, 0.8, 0.045)
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	Game.add_mesh(holder, beam, beam_mat, Vector3(0, 3.0, 0))

	var cp := {"pos": ground_pos + Vector3(0, 0.7, 0), "light": light,
		"core_mat": core_mat, "active": start_active, "holder": holder,
		"beam_mat": beam_mat}
	_checkpoints.append(cp)
	var idx := _checkpoints.size() - 1

	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.4, 3.0, 5.0)
	cs.shape = box
	cs.position.y = 1.0
	area.add_child(cs)
	holder.add_child(area)
	cp["area"] = area
	area.body_entered.connect(func(b: Node3D) -> void:
		if b is Player:
			_activate_checkpoint(idx))
	if start_active:
		light.light_energy = 1.5


func _gate_checkpoints_in_arenas() -> void:
	## 把落在竞技场（触发点 → 封印门，含入口门后方）内的莲台先隐藏，
	## 清完怪后由 _reveal_arena_checkpoints() 显现；否则玩家可以在门口来回踩莲台无限回血。
	for cp in _checkpoints:
		var x: float = (cp["pos"] as Vector3).x
		for ai in _arenas.size():
			var a: Dictionary = _arenas[ai]
			var lo: float = minf(float(a["trigger_x"]), float(a["gate_x"])) - 4.0
			var hi: float = maxf(float(a["trigger_x"]), float(a["gate_x"])) + 1.5
			if x > lo and x < hi:
				cp["arena_gate"] = ai
				_set_checkpoint_shown(cp, false)
				break


func _set_checkpoint_shown(cp: Dictionary, show: bool) -> void:
	var h = cp.get("holder")
	if h != null and is_instance_valid(h):
		(h as Node3D).visible = show
	var ar = cp.get("area")
	if ar != null and is_instance_valid(ar):
		(ar as Area3D).monitoring = show


func _reveal_arena_checkpoints(idx: int) -> void:
	## 清怪后让场地里的莲台显现；若玩家正站在莲台位置上，直接结算一次回血。
	for i in _checkpoints.size():
		var cp: Dictionary = _checkpoints[i]
		if not cp.has("arena_gate") or int(cp["arena_gate"]) != idx:
			continue
		_set_checkpoint_shown(cp, true)
		Game.burst(self, cp["pos"], Color(0.5, 1.0, 0.75), 24, 5.0, 0.08, 0.7)
		if player and is_instance_valid(player):
			var cp_pos: Vector3 = cp["pos"] as Vector3
			if absf(player.global_position.x - cp_pos.x) < 1.6 \
					and absf(player.global_position.y - (cp_pos.y - 0.7)) < 3.0:
				_activate_checkpoint(i)


func _hide_arena_checkpoints(idx: int) -> void:
	for cp in _checkpoints:
		if cp.has("arena_gate") and int(cp["arena_gate"]) == idx:
			_set_checkpoint_shown(cp, false)


func _activate_checkpoint(idx: int) -> void:
	var cp: Dictionary = _checkpoints[idx]
	# 竞技场里的莲台要等清完怪才出现；否则可以无限回血
	if cp.has("arena_gate"):
		var ai := int(cp["arena_gate"])
		if ai >= 0 and ai < _arenas.size() and not bool(_arenas[ai]["done"]):
			return
	checkpoint_pos = cp["pos"]
	player.heal(player.MAX_HP)   # 补血放在 active 判断之前：路过就能回血
	if cp["active"]:
		return
	cp["active"] = true
	Game.play_sfx("checkpoint", -4.0)
	hud.show_message("莲台已铭刻 · 气血充盈", 1.8, 38)
	var light: OmniLight3D = cp["light"]
	var tw := light.create_tween()
	tw.tween_property(light, "light_energy", 3.5, 0.3)
	tw.tween_property(light, "light_energy", 1.5, 0.8)
	var bm: StandardMaterial3D = cp["beam_mat"]
	var btw := create_tween()
	btw.tween_property(bm, "albedo_color:a", 0.13, 0.5)
	Game.burst(self, checkpoint_pos, Color(0.5, 1.0, 0.75), 30, 5.0, 0.08, 0.9)


func _make_gate(x: float, ybase: float, h := 5.5) -> StaticBody3D:
	var gate := StaticBody3D.new()
	gate.collision_layer = 1
	gate.collision_mask = 0
	gate.position = Vector3(x, ybase + h / 2.0, 0)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.7, h, 5.0)
	col.shape = shape
	gate.add_child(col)
	var seal_mat := Game.std_mat(gate_color * Color(1, 1, 1, 0.55),
		gate_glow, 1.5, 0.3)
	seal_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# 原来这里是一整块紫色板，在 Boss 区看起来像"一堵紫墙"；改成竖栏杆 + 能量薄片
	var bar := CylinderMesh.new()
	bar.top_radius = 0.055
	bar.bottom_radius = 0.055
	bar.height = h
	var bar_mat := Game.std_mat(gate_color.lightened(0.15), gate_glow,
		1.3, 0.3, 0.65)
	for i in 7:
		Game.add_mesh(gate, bar, bar_mat, Vector3(0, 0, -2.1 + i * 0.7))
	var beam_m := BoxMesh.new()
	beam_m.size = Vector3(0.1, 0.13, 4.4)
	for yy in [-h * 0.28, h * 0.28]:
		Game.add_mesh(gate, beam_m, bar_mat, Vector3(0, yy, 0))
	var sheet := BoxMesh.new()
	sheet.size = Vector3(0.04, h * 0.9, 4.2)
	var sheet_mat := Game.std_mat(gate_color * Color(1, 1, 1, 0.14),
		gate_glow, 1.1, 0.2)
	sheet_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sheet_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	Game.add_mesh(gate, sheet, sheet_mat, Vector3.ZERO)
	# 中间的封印符文环
	var seal_ring := TorusMesh.new()
	seal_ring.inner_radius = 0.55
	seal_ring.outer_radius = 0.62
	var ring_mat := Game.std_mat(gate_glow.lightened(0.25) * Color(1, 1, 1, 0.7),
		gate_glow.lightened(0.2), 1.8, 0.3)
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	Game.add_mesh(gate, seal_ring, ring_mat, Vector3(0, 0, 0), Vector3(90, 0, 0))
	# 两侧石柱
	var pillar := CylinderMesh.new()
	pillar.top_radius = 0.35
	pillar.bottom_radius = 0.45
	pillar.height = h + 1.0
	Game.add_mesh(gate, pillar, mat_stone_dark, Vector3(0, 0, 2.4))
	Game.add_mesh(gate, pillar, mat_stone_dark, Vector3(0, 0, -2.4))
	# 封印符粒子
	var p := GPUParticles3D.new()
	p.amount = 16
	p.lifetime = 1.8
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.3, h / 2.0, 2.2)
	pm.direction = Vector3(0, 1, 0)
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.6
	pm.gravity = Vector3.ZERO
	pm.color = Color(0.7, 0.4, 1.0, 0.4)
	p.process_material = pm
	var dm := SphereMesh.new()
	dm.radius = 0.05
	dm.height = 0.1
	dm.radial_segments = 4
	dm.rings = 2
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.75, 0.45, 1.0, 0.6)
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.material = dmat
	p.draw_pass_1 = dm
	gate.add_child(p)
	add_child(gate)
	return gate


func _open_gate(gate: Node3D) -> void:
	if gate == null or not is_instance_valid(gate):
		return
	Game.play_sfx("gate", -4.0)
	Game.burst(self, gate.global_position, gate_glow, 30, 6.0, 0.09, 0.8)
	var tw := gate.create_tween()
	tw.tween_property(gate, "position:y", gate.position.y - 8.0, 1.2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(gate.queue_free)


func _add_trigger(x: float, y: float, w: float, h: float,
		cb: Callable) -> Area3D:
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	area.position = Vector3(x, y, 0)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(w, h, 5.0)
	cs.shape = box
	area.add_child(cs)
	add_child(area)
	area.body_entered.connect(func(b: Node3D) -> void:
		if b is Player and not area.get_meta("fired", false):
			area.set_meta("fired", true)
			cb.call())
	return area


func _lock_arena(gate_x: float, gate_y: float, trigger_x: float,
		spawns: Array, title := "封印结界 · 斩除异化之物") -> void:
	## 通用"清怪开门"竞技场：spawns 为 Callable 数组，返回 EnemyBase
	var gate := _make_gate(gate_x, gate_y)
	var arena := {"gate": gate, "enemies": [], "done": false,
		"trigger_x": trigger_x, "gate_y": gate_y, "gate_x": gate_x,
		"spawns": spawns, "title": title}
	_arenas.append(arena)
	var idx := _arenas.size() - 1
	var trigger := _add_trigger(trigger_x, gate_y + 1.5, 3.0, 4.0,
		func() -> void: _start_arena(idx, spawns, title))
	trigger.set_meta("arena_idx", idx)
	arena["trigger"] = trigger
	if gate_x == 0.0:
		gate.visible = false


func _start_arena(idx: int, spawns: Array, title: String) -> void:
	var arena: Dictionary = _arenas[idx]
	if arena["done"]:
		return
	hud.show_message(title, 2.0, 42)
	Game.play_sfx("roar", -10.0, 1.6)
	# 入口侧补一道封印墙：触发后真正"困住"玩家，清怪后与出口一起打开。
	# 位置默认在触发点后 2.4m；若正好压到莲台，再往后挪 1.4m（避免复活点卡在墙里）。
	if not arena.has("back_gate") or not is_instance_valid(arena["back_gate"]):
		var back_x: float = float(arena.get("trigger_x", 0.0)) - 2.4
		for cp: Dictionary in _checkpoints:
			if absf((cp["pos"] as Vector3).x - back_x) < 2.0:
				back_x = float(arena.get("trigger_x", 0.0)) - 3.8
				break
		var back: StaticBody3D = _make_gate(back_x, float(arena.get("gate_y", 0.0)),
			5.5)
		arena["back_gate"] = back
		Game.burst(self, Vector3(back_x, float(arena.get("gate_y", 0.0)) + 3.0, 0),
			gate_glow, 24, 5.0, 0.09, 0.6)
	for spawner: Callable in spawns:
		var e: EnemyBase = spawner.call()
		arena["enemies"].append(e)
		Game.burst(self, e.global_position, Color(0.5, 0.25, 0.8), 20, 5.0,
			0.08, 0.6)
		e.enemy_died.connect(func(_e: EnemyBase) -> void: _on_arena_death(idx))


func _on_arena_death(idx: int) -> void:
	var arena: Dictionary = _arenas[idx]
	if arena["done"]:
		return
	if not _arena_clear(arena):
		return
	arena["done"] = true
	hud.show_message("封 印 已 解", 2.0, 48)
	_open_gate(arena["gate"])
	if arena.has("back_gate"):
		_open_gate(arena["back_gate"])
		arena["back_gate"] = null
	# 场地里的莲台在清怪后才显现
	_reveal_arena_checkpoints(idx)


func _arena_clear(arena: Dictionary) -> bool:
	## 场地内是否已经没有活怪（含分裂子体 / Boss 召唤物）
	for e in arena["enemies"]:
		if is_instance_valid(e) and not (e as EnemyBase).dead:
			return false
	var lo: float = minf(float(arena["trigger_x"]), float(arena["gate_x"])) - 3.0
	var hi: float = maxf(float(arena["trigger_x"]), float(arena["gate_x"])) + 3.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or (e as EnemyBase).dead:
			continue
		var x: float = (e as Node3D).global_position.x
		if x > lo and x < hi:
			return false
	return true


func _poll_arenas() -> void:
	for i in _arenas.size():
		var arena: Dictionary = _arenas[i]
		if arena["done"]:
			continue
		if (arena["enemies"] as Array).is_empty():
			continue
		if _arena_clear(arena):
			_on_arena_death(i)


# ================================================================ 敌人

func _spawn_crawler(x: float, y: float, pmin: float,
		pmax: float) -> EnemyCrawler:
	var e := EnemyCrawler.new()
	e.position = Vector3(x, y + 0.2, 0)
	e.patrol_min = pmin
	e.patrol_max = pmax
	add_child(e)
	return e


func _spawn_shooter(x: float, y: float, rmin: float,
		rmax: float) -> EnemyShooter:
	var e := EnemyShooter.new()
	e.position = Vector3(x, y, 0)
	e.range_min = rmin
	e.range_max = rmax
	add_child(e)
	return e


func _spawn_wraith(x: float, y: float, pmin: float,
		pmax: float) -> EnemyWraith:
	## 潮魇：悬浮突进怪。y 即悬浮高度，不要贴地生成。
	var e := EnemyWraith.new()
	e.position = Vector3(x, y, 0)
	e.spawn_y = y
	e.patrol_min = pmin
	e.patrol_max = pmax
	add_child(e)
	return e


func _spawn_bomber(x: float, y: float) -> EnemyBomber:
	## 渊爆水母：自爆怪。y 即悬浮高度。
	var e := EnemyBomber.new()
	e.position = Vector3(x, y, 0)
	e.hover_y = y
	add_child(e)
	return e


func _spawn_divider(x: float, y: float, pmin: float,
		pmax: float) -> EnemyDivider:
	## 分潮：会分裂的地面怪（母体死亡后裂成两只子体）
	var e := EnemyDivider.new()
	e.position = Vector3(x, y + 0.2, 0)
	e.patrol_min = pmin
	e.patrol_max = pmax
	add_child(e)
	return e


func _spawn_guard(x: float, y: float, pmin: float,
		pmax: float) -> EnemyGuard:
	## 狱卒：正面举盾、重击/背刺才有效
	var e := EnemyGuard.new()
	e.position = Vector3(x, y + 0.2, 0)
	e.patrol_min = pmin
	e.patrol_max = pmax
	add_child(e)
	return e


func _spawn_turret(x: float, y: float) -> EnemyTurret:
	## 囚晶：固定炮台，不会移动
	var e := EnemyTurret.new()
	e.position = Vector3(x, y, 0)
	add_child(e)
	return e


# ================================================================ Boss 流程

func _setup_boss(boss_node: EnemyBase, name_text: String,
		min_x: float, max_x: float, ground_y: float,
		gate_x: float, trigger_x: float) -> void:
	boss = boss_node
	boss_name = name_text
	arena_min_x = min_x
	arena_max_x = max_x
	arena_ground_y = ground_y
	boss_gate_x = gate_x
	boss_trigger_x = trigger_x
	# Boss 自己也需要场地范围：它的砸地/横扫目标点是用自身字段算的。
	# 之前只写了关卡字段，Boss 的 arena_min_x/arena_max_x/ground_y 一直是 0，
	# 砸地目标被 clamp 到 x≈0（关卡起点），表现为"Boss 突然瞬移到起点再回来"。
	if "arena_min_x" in boss_node:
		boss_node.set("arena_min_x", min_x)
	if "arena_max_x" in boss_node:
		boss_node.set("arena_max_x", max_x)
	if "ground_y" in boss_node:
		boss_node.set("ground_y", ground_y)
	if "home_pos" in boss_node:
		boss_node.set("home_pos", boss_node.global_position)
	if boss_node.has_method("_sync_arena"):
		boss_node.call("_sync_arena")
	if boss.has_signal("boss_hp_changed"):
		boss.connect("boss_hp_changed", hud.on_boss_hp)
	if boss.has_signal("summon_requested"):
		boss.connect("summon_requested", _on_boss_summon)
	if boss.has_signal("boss_defeated"):
		boss.connect("boss_defeated", _on_boss_defeated)
	hud.set_boss_name(name_text, boss_name_color)
	hud.set_boss_portrait(boss_portrait)
	boss_trigger = _add_trigger(trigger_x, ground_y + 2.0, 3.0, 5.0,
		_start_boss)


func _start_boss() -> void:
	if boss == null or boss_started or boss.dead:
		return
	boss_started = true
	boss_gate = _make_gate(boss_gate_x, arena_ground_y, 7.0)
	Game.burst(self, Vector3(boss_gate_x, arena_ground_y + 3.0, 0),
		gate_glow, 30, 6.0, 0.1, 0.7)
	hud.show_message(boss_name, 2.4, 56)
	hud.show_boss_bar(true)
	hud.show_hints(false)
	# 双目标取景：Boss 在 30 米宽场地里移动时不会跑出画面
	# （之前只跟玩家，Boss 不断进出画面边缘，看起来像"反复闪现"）
	cam.set_focus_target(boss)
	cam.set_framing(1.0, 1.2)
	boss.call("activate")


func _on_boss_summon(count: int) -> void:
	hud.show_message("深渊的爪牙涌出……", 1.5, 36)
	for i in count:
		var x := lerpf(arena_min_x + 5.0, arena_max_x - 5.0,
			float(i) / maxf(count - 1, 1))
		var pmin := arena_min_x + 1.5
		var pmax := arena_max_x - 1.5
		var e: EnemyBase
		match summon_unit:
			"guard":
				e = _spawn_guard(x, arena_ground_y, pmin, pmax)
			"wraith":
				e = _spawn_wraith(x, arena_ground_y + 2.6, pmin, pmax)
			"bomber":
				e = _spawn_bomber(x, arena_ground_y + 2.4)
			_:
				e = _spawn_crawler(x, arena_ground_y + 1.0, pmin, pmax)
		Game.burst(self, e.global_position, Color(0.5, 0.25, 0.8), 20, 5.0,
			0.08, 0.6)
		_boss_summons.append(e)


func _clear_boss_summons() -> void:
	## Boss 死亡或玩家阵亡重置时，把 Boss 召出的小怪一并清掉，
	## 避免"Boss 死了/重开了，场地上还堆着一群小怪"。
	for e in _boss_summons:
		if is_instance_valid(e) and not (e as EnemyBase).dead:
			Game.burst(self, (e as Node3D).global_position,
				Color(0.5, 0.25, 0.8), 16, 4.5, 0.09, 0.5)
			(e as Node3D).queue_free()
	_boss_summons.clear()
	# 兜底：Boss 场地范围内还活着的怪也一起清掉
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or (e as EnemyBase).dead:
			continue
		var x: float = (e as Node3D).global_position.x
		if x > arena_min_x - 2.0 and x < arena_max_x + 2.0:
			(e as Node3D).queue_free()


func _on_boss_defeated() -> void:
	hud.show_boss_bar(false)
	hud.show_hints(true)
	cam.set_focus_target(null)
	cam.set_framing(0.0, 0.0)
	Game.run_active = false
	_clear_boss_summons()
	if boss_gate:
		_open_gate(boss_gate)
		boss_gate = null
	hud.show_message(boss_defeat_msg, 2.6, 56)
	await get_tree().create_timer(1.8, false).timeout
	_spawn_portal()


func _spawn_portal() -> void:
	var holder := Node3D.new()
	holder.position = Vector3(lerpf(arena_min_x, arena_max_x, 0.55),
		arena_ground_y + 2.2, 0)
	add_child(holder)
	var torus := TorusMesh.new()
	torus.inner_radius = 1.5
	torus.outer_radius = 1.75
	var mat := Game.std_mat(Color(1.0, 0.85, 0.4), Color(1.0, 0.75, 0.25),
		2.2, 0.3)
	var ring := Game.add_mesh(holder, torus, mat, Vector3.ZERO,
		Vector3(90, 0, 0))
	_floaters.append({"node": ring, "speed": 0.8, "axis": "z"})
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.8, 0.4)
	light.light_energy = 3.0
	light.omni_range = 10.0
	light.light_volumetric_fog_energy = 0.4
	holder.add_child(light)
	Game.tune_light(light, 1.5, 8.0, 0.25)
	var p := GPUParticles3D.new()
	p.amount = 40
	p.lifetime = 1.5
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 1.6
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 1.0
	pm.gravity = Vector3(0, 0.5, 0)
	pm.color = Color(1.0, 0.85, 0.45, 0.5)
	p.process_material = pm
	var dm := SphereMesh.new()
	dm.radius = 0.05
	dm.height = 0.1
	dm.radial_segments = 4
	dm.rings = 2
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(1.0, 0.9, 0.5, 0.7)
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.material = dmat
	p.draw_pass_1 = dm
	holder.add_child(p)
	Game.burst(self, holder.position, Color(1.0, 0.85, 0.4), 40, 7.0, 0.1, 1.0)
	Game.play_sfx("checkpoint", 0.0, 0.8)
	hud.show_message(portal_msg, 2.2, 40)

	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.6
	cs.shape = sph
	area.add_child(cs)
	holder.add_child(area)
	area.body_entered.connect(func(b: Node3D) -> void:
		if b is Player and not area.get_meta("fired", false):
			area.set_meta("fired", true)
			player.invuln = 99.0
			Game.play_sfx("checkpoint", -2.0, 0.9)
			Game.mark_cleared(chapter_id)
			hud.victory_chapter = chapter_title
			if Game.campaign:
				# 闯关模式：本章结束直接进下一章；最后一章才结算
				var nxt := Game.campaign_next_chapter()
				if nxt != "":
					Game.enter_campaign_chapter(nxt)
					Game.change_scene(Game.campaign_scene(nxt))
				else:
					hud.victory_chapter = "三章皆通 · 归 墟 暂 封"
					hud.show_victory()
			elif next_scene != "":
				Game.change_scene(next_scene)
			else:
				hud.show_victory())


# ================================================================ 生死循环

func _on_player_died() -> void:
	# 闯关模式：整关刷新，从本章出生点重来；选关模式：莲台复活
	if Game.campaign:
		hud.show_campaign_death(chapter_title)
	else:
		hud.show_death()


func _reset_boss_fight() -> void:
	## Boss 战中阵亡或坠渊：完整重置 Boss、封门与触发器
	if boss == null or not boss_started or not is_instance_valid(boss):
		return
	if boss.has_method("reset_fight"):
		boss.call("reset_fight")
	boss_started = false
	hud.show_boss_bar(false)
	hud.show_hints(true)
	cam.set_focus_target(null)
	cam.set_framing(0.0, 0.0)   # 回到常规取景
	if boss_gate and is_instance_valid(boss_gate):
		boss_gate.queue_free()
		boss_gate = null
	# 复用同一个触发器：重置 fired 标记即可（原来每次重生都新建一个触发区，会越积越多）
	if boss_trigger and is_instance_valid(boss_trigger):
		boss_trigger.set_meta("fired", false)
	# 玩家阵亡重置：Boss 召出的小怪也一并清场
	_clear_boss_summons()
	hud.show_message("渊狱兽沉回了深处……", 1.6, 34)


func _respawn_full() -> void:
	Game.flash_fade(0.5)
	await get_tree().create_timer(0.25, false).timeout
	_reset_boss_fight()
	player.respawn(checkpoint_pos)
	_reset_active_arenas()
	cam.snap_to_target()


func _reset_active_arenas() -> void:
	## 玩家在本关内复活/坠渊时，把"已触发但未清完"的竞技场重置回未触发状态。
	## 否则入口封印墙会把复活后的玩家挡在场外，永远清不到怪、门也永远不开。
	for i in _arenas.size():
		var a: Dictionary = _arenas[i]
		if a["done"]:
			continue
		var enemies: Array = a["enemies"]
		if enemies.is_empty():
			continue
		var lo: float = minf(float(a["trigger_x"]), float(a["gate_x"])) - 4.0
		var hi: float = maxf(float(a["trigger_x"]), float(a["gate_x"])) + 4.0
		# 直接释放：不走 die()，避免触发竞技场计数把门误开
		for e in enemies:
			if is_instance_valid(e):
				e.queue_free()
		for e in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(e):
				continue
			var x: float = (e as Node3D).global_position.x
			if x > lo and x < hi:
				e.queue_free()
		enemies.clear()
		# 移除入口封印墙，让玩家可以重新进入
		if a.has("back_gate") and is_instance_valid(a["back_gate"]):
			(a["back_gate"] as Node3D).queue_free()
		a["back_gate"] = null
		# 触发区重新可触发
		var t = a.get("trigger")
		if t != null and is_instance_valid(t):
			t.set_meta("fired", false)
		# 场地里的莲台重新隐藏（还没清怪）
		_hide_arena_checkpoints(i)
		# 复活点已经在场地内：直接重新开战（等玩家再走进来会被入口墙卡住）
		var px: float = player.global_position.x
		if px > lo + 2.0 and px < hi - 2.0:
			_start_arena(i, a["spawns"], a["title"])


func _physics_process(_delta: float) -> void:
	if player == null or player.act == "dead":
		return
	if player.global_position.y < kill_y:
		player.take_damage(8.0, player.global_position.x + 1.0)
		if player.act != "dead":
			_reset_boss_fight()
			Game.flash_fade(0.4)
			player.global_position = checkpoint_pos
			player.velocity = Vector3.ZERO
			player.invuln = maxf(player.invuln, 1.0)
			_reset_active_arenas()
			cam.snap_to_target()


# ================================================================ 每帧

func _process(delta: float) -> void:
	_t += delta
	_update_zone_ambience(delta)
	# 竞技场兜底轮询：分裂怪的子体 / 召唤怪没有单独连信号，
	# 用低频轮询检查"场地内是否还有活怪"，避免封印墙不开或开了还有怪。
	_arena_poll_t += delta
	if _arena_poll_t >= 0.35:
		_arena_poll_t = 0.0
		_poll_arenas()
	if spawn_wildlife:
		_update_wildlife(delta)
	for f in _floaters:
		var node: Node3D = f["node"]
		if not is_instance_valid(node):
			continue
		match f["axis"]:
			"z":
				node.rotation.y += delta * f["speed"]
			"spin_z":
				node.rotation.z += delta * f["speed"]
			"y":
				node.position.y = f["base_y"] + \
					sin(_t * f["speed"] + f["phase"]) * f["bob"]
				node.rotation.y += delta * 0.1
			"sway":
				node.rotation.z = f["base"] + sin(_t * f["speed"]) * 0.12
			"patrol":
				node.position.x = f["base_x"] + \
					sin(_t * TAU / f["speed"]) * f["travel"]


func _zone_sample(x: float) -> Array:
	## 按 x 在 zone_stops 里插值，返回 [雾色, 环境光色, 雾反照率]
	if zone_stops.is_empty():
		return [Color(0.05, 0.16, 0.2), Color(0.25, 0.4, 0.45),
			Color(0.3, 0.6, 0.65)]
	var fog: Color = zone_stops[0][1]
	var amb: Color = zone_stops[0][2]
	var va: Color = zone_stops[0][3]
	for i in zone_stops.size() - 1:
		var a: Array = zone_stops[i]
		var b: Array = zone_stops[i + 1]
		if x >= a[0]:
			var t := clampf((x - a[0]) / (b[0] - a[0]), 0.0, 1.0)
			t = t * t * (3.0 - 2.0 * t)
			fog = (a[1] as Color).lerp(b[1], t)
			amb = (a[2] as Color).lerp(b[2], t)
			va = (a[3] as Color).lerp(b[3], t)
	return [fog, amb, va]


func _update_zone_ambience(delta: float) -> void:
	if player == null or not is_instance_valid(player) or _env == null:
		return
	var s := _zone_sample(player.global_position.x)
	var k := clampf(2.5 * delta, 0.0, 1.0)
	_env.fog_light_color = _env.fog_light_color.lerp(s[0], k)
	_env.ambient_light_color = _env.ambient_light_color.lerp(s[1], k)
	_env.volumetric_fog_albedo = _env.volumetric_fog_albedo.lerp(s[2], k)
	var t := clampf((player.global_position.x - zone_stops[0][0]) / 150.0,
		0.0, 1.0)
	var sun_c := Color(0.75, 0.95, 1.0).lerp(Color(0.95, 0.62, 0.6), t)
	if _sun:
		_sun.light_color = _sun.light_color.lerp(sun_c, k)


func _update_wildlife(delta: float) -> void:
	if _whale:
		var ph := fposmod(_t * 0.45 + _whale_seed, TAU)
		var prog := fposmod(_t * 3.2, 260.0)
		if prog < delta * 3.2 + 0.1:
			_whale_seed = randf() * TAU
		_whale.position = Vector3(-50.0 + prog,
			8.0 + sin(ph) * 1.8 + sin(_whale_seed * 3.0) * 3.0, -34.0)
		_whale.rotation.z = sin(ph) * 0.06
		if _whale_tail:
			_whale_tail.rotation.y = sin(_t * 2.6) * 0.35
	for i in _fish.size():
		var f := _fish[i]
		if not is_instance_valid(f):
			continue
		var anchor := Vector3(fposmod(_t * 5.5, 230.0) - 25.0,
			5.0 + sin(_t * 0.6) * 1.6, -13.5)
		f.position = anchor + Vector3(sin(_t * 2.0 + i * 1.3) * 1.4 +
			(i % 3) * 0.7, cos(_t * 1.7 + i * 0.9) * 0.8,
			sin(_t * 1.2 + i * 0.6) * 0.6)
		f.rotation.z = cos(_t * 2.0 + i * 1.3) * 0.2


# ================================================================ 装饰积木

# ================================================================ 现成素材（Poly Haven, CC0）
## 环境装饰优先用现成模型；文件缺失时自动回落程序化几何，
## 保证美术管线断裂时游戏仍能跑（"不改变基本功能"的保险丝）。
## 模型由 tools/blender/prepare_props.py 批处理导出（已减面、原点在脚底中心）。
const PROP_LANTERN := "res://art/models/props/lantern.glb"
const PROP_CHANDELIER := "res://art/models/props/chandelier.glb"
const PROP_STATUE := "res://art/models/props/statue.glb"
const PROP_ROCKS: Array[String] = [
	"res://art/models/props/rock_a.glb",
	"res://art/models/props/rock_b.glb",
	"res://art/models/props/rock_c.glb",
]
## 灯饰风格：第一章提灯 / 第二章龙宫深狱用吊灯（子类可覆盖）
var lantern_style := "lantern"


func _prop(path: String, height: float, yaw := 0.0, vis_end := 0.0) -> Node3D:
	## 载入现成 GLB 道具并归一化到 height。
	## glTF 已经是 Y 轴朝上，所以 pitch 传 0（角色模型那种 TripoSR 才需要 -90）。
	## 不存在时返回 null，调用方走程序化兜底。
	var node := Game.load_model(path, height, yaw, 0.0, vis_end)
	if node:
		_tune_prop_materials(node)
	return node


func _tune_prop_materials(root: Node3D, tint := Color(0.05, 0.11, 0.15),
		energy := 0.5) -> void:
	## 现成素材是写实 PBR，在本作蓝雾 + 低照度的场景里容易糊成黑影。
	## 给材质补一点冷色自发光，让轮廓和材质细节能读出来；只改材质，不碰任何玩法数值。
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true,
			false):
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s) as BaseMaterial3D
			if m == null:
				continue
			m.emission_enabled = true
			m.emission = tint
			m.emission_energy_multiplier = energy


func _prop_sized(path: String, target_max: float, yaw := 0.0,
		vis_end := 0.0) -> Node3D:
	## 按"最大边长"归一化的道具加载器（岩石这类扁扫描件用）。
	## 按高度缩放会把扁平石块拉成薄片，所以统一按最长边缩放并底部对齐 y=0。
	if not ResourceLoader.exists(path):
		return null
	var ps := load(path) as PackedScene
	if ps == null:
		return null
	var inst := ps.instantiate() as Node3D
	if inst == null:
		return null
	var meshes := inst.find_children("*", "MeshInstance3D", true, false)
	if meshes.is_empty():
		inst.free()
		return null
	var wrapper := Node3D.new()
	wrapper.rotation.y = deg_to_rad(yaw)
	wrapper.add_child(inst)
	add_child(wrapper)            # 需要入树才能算 global_transform
	for mi: MeshInstance3D in meshes:
		mi.lod_bias = 1.4
		mi.extra_cull_margin = 0.6
		if vis_end > 0.0:
			mi.visibility_range_end = vis_end
			mi.visibility_range_fade_mode = \
				GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	var mn := Vector3(INF, INF, INF)
	var mx := -mn
	for mi: MeshInstance3D in meshes:
		var box: AABB = mi.global_transform * mi.get_aabb()
		mn = mn.min(box.position)
		mx = mx.max(box.position + box.size)
	var biggest := maxf(maxf(mx.x - mn.x, mx.y - mn.y), mx.z - mn.z)
	var s := target_max / maxf(biggest, 0.0001)
	inst.scale = Vector3(s, s, s)
	# 缩放后重新量一次，把脚底放到 wrapper 原点、水平居中
	mn = Vector3(INF, INF, INF)
	mx = -mn
	for mi: MeshInstance3D in meshes:
		var box2: AABB = mi.global_transform * mi.get_aabb()
		mn = mn.min(box2.position)
		mx = mx.max(box2.position + box2.size)
	inst.position -= Vector3((mn.x + mx.x) * 0.5, mn.y, (mn.z + mx.z) * 0.5)
	_tune_prop_materials(wrapper)
	return wrapper


func _decor_pillar(x: float, z: float, rng: RandomNumberGenerator,
		top_broken := true) -> void:
	# 现成素材：约 1/7 的背景断柱换成 Poly Haven 哥特石像（"龙宫遗构"）。
	# 这里用独立 RNG，避免多消耗一次 randf 打乱调用方的随机序列。
	var key := int(round(x)) * 7 + int(round(z))
	if posmod(key, 7) == 0:
		var srng := RandomNumberGenerator.new()
		srng.seed = absi(key) * 7919 + 13
		var statue := _prop(PROP_STATUE, srng.randf_range(4.5, 8.0),
			srng.randf_range(0, 360), 160.0)
		if statue:
			statue.position = Vector3(x, -4.0, z)
			add_child(statue)
			return
	var h := rng.randf_range(6.0, 14.0)
	var holder := Node3D.new()
	holder.position = Vector3(x, -4.0, z)
	holder.rotation_degrees = Vector3(rng.randf_range(-6, 6), 0,
		rng.randf_range(-7, 7))
	add_child(holder)
	var r0 := rng.randf_range(0.55, 0.95)
	var cyl := CylinderMesh.new()
	cyl.top_radius = r0 * 0.85
	cyl.bottom_radius = r0
	cyl.height = h
	Game.add_mesh(holder, cyl, mat_stone_dark, Vector3(0, h / 2.0, 0))
	# 柱础
	var foot := BoxMesh.new()
	foot.size = Vector3(r0 * 3.0, 0.5, r0 * 3.0)
	Game.add_mesh(holder, foot, mat_rock, Vector3(0, 0.25, 0))
	# 柱头（部分断裂：偏斜的残块）
	if rng.randf() < 0.7:
		var cap := BoxMesh.new()
		cap.size = Vector3(r0 * 2.6, 0.45, r0 * 2.6)
		var tilt := 0.0 if not top_broken else rng.randf_range(-18, 18)
		Game.add_mesh(holder, cap, mat_stone_dark,
			Vector3(rng.randf_range(-0.2, 0.2), h + 0.22, 0),
			Vector3(0, rng.randf_range(0, 45), tilt))


func _decor_great_ring(x: float, z: float, r: float,
		mat: StandardMaterial3D) -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = r - 0.5
	torus.outer_radius = r
	var mi := Game.add_mesh(self, torus, mat, Vector3(x, 2.0, z),
		Vector3(90, 0, 0))
	_floaters.append({"node": mi, "speed": 0.05, "axis": "z"})


func _decor_crystal(pos: Vector3, cyan: bool, rng: RandomNumberGenerator,
		with_light := false) -> void:
	## 晶簇：3~5 根长短不一的棱柱，底部埋进地面，带低自发光 + 边缘光
	var holder := Node3D.new()
	holder.position = pos
	add_child(holder)
	var mat := mat_crystal_c if cyan else mat_crystal_p
	var n := rng.randi_range(3, 5)
	for i in n:
		var prism := PrismMesh.new()
		var h := rng.randf_range(0.45, 1.35)
		var w := rng.randf_range(0.12, 0.26)
		prism.size = Vector3(w, h, w * 0.8)
		Game.add_mesh(holder, prism, mat,
			Vector3(rng.randf_range(-0.32, 0.32), h * 0.42 - 0.12,
				rng.randf_range(-0.24, 0.24)),
			Vector3(rng.randf_range(-14, 14), rng.randf_range(0, 360),
				rng.randf_range(-14, 14)))
	# 基座碎石
	var base := CylinderMesh.new()
	base.top_radius = 0.26
	base.bottom_radius = 0.4
	base.height = 0.16
	Game.add_mesh(holder, base, mat_rock, Vector3(0, -0.04, 0))
	if with_light:
		var light := OmniLight3D.new()
		light.light_color = Color(0.3, 0.85, 0.85) if cyan \
			else Color(0.6, 0.35, 0.9)
		light.light_energy = 0.9
		light.omni_range = 4.5
		light.light_volumetric_fog_energy = 0.2
		light.position = Vector3(0, 0.7, 0)
		light.shadow_enabled = false
		holder.add_child(light)
		Game.tune_light(light, 0.5, 3.8, 0.0)


func _decor_kelp(x: float, z: float, rng: RandomNumberGenerator) -> void:
	var holder := Node3D.new()
	holder.position = Vector3(x, -6.5, z)
	add_child(holder)
	for i in rng.randi_range(2, 4):
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.02
		cyl.bottom_radius = 0.07
		cyl.height = rng.randf_range(2.0, 5.0)
		var k := Game.add_mesh(holder, cyl, mat_kelp,
			Vector3(rng.randf_range(-0.6, 0.6), cyl.height / 2.0,
				rng.randf_range(-0.4, 0.4)),
			Vector3(rng.randf_range(-10, 10), 0, rng.randf_range(-10, 10)))
		_floaters.append({"node": k, "speed": rng.randf_range(0.3, 0.7),
			"axis": "sway", "base": k.rotation.z})


func _decor_float_rock(pos: Vector3, rng: RandomNumberGenerator) -> void:
	## 现成素材：Poly Haven 岩石扫描模型（3 种加权轮换）；文件缺失时回落低模球。
	## 岩石是扁扫描件，用"最长边"归一化，避免按高度缩放出薄片。
	var roll := rng.randf()
	var path: String = PROP_ROCKS[2]          # boulder 为主
	if roll < 0.25:
		path = PROP_ROCKS[0]
	elif roll < 0.5:
		path = PROP_ROCKS[1]
	var model := _prop_sized(path, rng.randf_range(1.0, 2.6),
		rng.randf_range(0, 360), 90.0)
	if model:
		model.position = pos
		_floaters.append({"node": model, "speed": rng.randf_range(0.1, 0.3),
			"axis": "y", "bob": rng.randf_range(0.3, 0.8),
			"base_y": pos.y, "phase": rng.randf() * TAU})
		return
	var mesh := SphereMesh.new()
	mesh.radius = rng.randf_range(0.5, 1.4)
	mesh.height = mesh.radius * 1.4
	mesh.radial_segments = 8
	mesh.rings = 5
	var mi := Game.add_mesh(self, mesh, mat_rock, pos,
		Vector3(rng.randf_range(0, 360), rng.randf_range(0, 360), 0))
	_floaters.append({"node": mi, "speed": rng.randf_range(0.1, 0.3),
		"axis": "y", "bob": rng.randf_range(0.3, 0.8),
		"base_y": pos.y, "phase": rng.randf() * TAU})


func _decor_lantern(pos: Vector3) -> void:
	## 现成素材：Poly Haven 提灯（第二章换成龙宫吊灯）；缺失时回落发光球。
	var holder := Node3D.new()
	holder.position = pos
	add_child(holder)
	var model: Node3D = null
	if lantern_style == "chandelier":
		model = _prop(PROP_CHANDELIER, 1.15, randf() * 360.0, 80.0)
	if model == null:
		model = _prop(PROP_LANTERN, 0.62, randf() * 360.0, 80.0)
	if model:
		holder.add_child(model)
		# 灯具给暖色自发光，避免"提灯自己反而不亮"（只改材质，不影响光照逻辑）
		_tune_prop_materials(model, Color(0.55, 0.34, 0.14), 1.6)
	else:
		var shell := SphereMesh.new()
		shell.radius = 0.3
		shell.height = 0.6
		var mat := Game.std_mat(Color(0.95, 0.7, 0.35, 0.85),
			Color(1.0, 0.65, 0.25), 1.1, 0.4)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		Game.add_mesh(holder, shell, mat, Vector3.ZERO,
			Vector3.ZERO, Vector3(1, 1.25, 1))
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.65, 0.3)
	light.light_energy = 1.0
	light.omni_range = 6.0
	light.light_volumetric_fog_energy = 0.25
	light.shadow_enabled = false
	holder.add_child(light)
	Game.tune_light(light, 0.5, 4.2, 0.0)
	_floaters.append({"node": holder, "speed": 0.5, "axis": "y", "bob": 0.4,
		"base_y": pos.y, "phase": randf() * TAU})


func _decor_vortex(pos: Vector3, tint := Color(0.4, 0.15, 0.6)) -> void:
	## 归墟巨涡：背景中缓缓旋转的深渊之眼
	var holder := Node3D.new()
	holder.position = pos
	add_child(holder)
	var vt := Game.tex("res://art/vortex.png")
	if vt:
		var quad := QuadMesh.new()
		quad.size = Vector2(24, 24)
		var vm := ShaderMaterial.new()
		vm.shader = load("res://shaders/fx_sprite_fade.gdshader")
		vm.set_shader_parameter("tex", vt)
		vm.set_shader_parameter("tint", Color(0.85, 0.75, 1.0, 0.85))
		vm.set_shader_parameter("fade_start", 0.34)
		vm.set_shader_parameter("fade_end", 0.54)
		vm.set_shader_parameter("strength", 0.85)
		var vq := Game.add_mesh(holder, quad, vm, Vector3(0, 0, -1.5))
		_floaters.append({"node": vq, "speed": 0.12, "axis": "spin_z"})
	for i in 3:
		var torus := TorusMesh.new()
		torus.inner_radius = 3.0 + i * 2.2
		torus.outer_radius = 3.5 + i * 2.2
		var c := tint * (1.0 - i * 0.22)
		var mat := Game.std_mat(c, c, 1.0 - i * 0.25, 0.5)
		var mi := Game.add_mesh(holder, torus, mat, Vector3.ZERO,
			Vector3(90, 0, 0))
		_floaters.append({"node": mi, "speed": 0.3 - i * 0.08, "axis": "z"})
	var core := SphereMesh.new()
	core.radius = 2.2
	core.height = 4.4
	Game.add_mesh(holder, core, Game.std_mat(Color(0.04, 0.01, 0.08),
		tint * 0.35, 0.8, 0.6), Vector3.ZERO)


func _build_whale() -> void:
	## 远景巨鲸：缓缓横穿海渊
	_whale = Node3D.new()
	_whale.position = Vector3(-60, 8, -34)
	add_child(_whale)
	var dark := Game.std_mat(Color(0.05, 0.1, 0.16), Color(0.02, 0.05, 0.08),
		0.4, 0.9)
	var body := SphereMesh.new()
	body.radius = 1.0
	body.height = 2.0
	Game.add_mesh(_whale, body, dark, Vector3.ZERO,
		Vector3.ZERO, Vector3(3.6, 1.15, 0.95))
	var head := SphereMesh.new()
	head.radius = 0.95
	head.height = 1.9
	Game.add_mesh(_whale, head, dark, Vector3(2.2, 0.1, 0),
		Vector3.ZERO, Vector3(1.4, 1.0, 0.9))
	var fin := SphereMesh.new()
	fin.radius = 0.7
	fin.height = 1.4
	Game.add_mesh(_whale, fin, dark, Vector3(0.8, -0.7, 0.5),
		Vector3(20, 0, -30), Vector3(1.2, 0.18, 0.5))
	Game.add_mesh(_whale, fin, dark, Vector3(0.8, -0.7, -0.5),
		Vector3(-20, 0, -30), Vector3(1.2, 0.18, 0.5))
	_whale_tail = Node3D.new()
	_whale_tail.position = Vector3(-3.2, 0.1, 0)
	_whale.add_child(_whale_tail)
	Game.add_mesh(_whale_tail, fin, dark, Vector3(-0.8, 0, 0),
		Vector3.ZERO, Vector3(1.1, 0.25, 1.9))
	var spot := SphereMesh.new()
	spot.radius = 0.07
	spot.height = 0.14
	var spot_mat := Game.std_mat(Color(0.4, 0.85, 0.85),
		Color(0.35, 0.8, 0.8), 1.5, 0.4)
	for i in 7:
		Game.add_mesh(_whale, spot, spot_mat,
			Vector3(-2.0 + i * 0.7, 0.75 + sin(i * 1.1) * 0.2,
				0.35 * (1 if i % 2 == 0 else -1)))


func _build_fish_school() -> void:
	var fish_mat := Game.std_mat(Color(0.15, 0.35, 0.4),
		Color(0.1, 0.35, 0.38), 0.8, 0.6)
	var fm := SphereMesh.new()
	fm.radius = 0.16
	fm.height = 0.32
	fm.radial_segments = 6
	fm.rings = 3
	for i in 7:
		var f := Game.add_mesh(self, fm, fish_mat, Vector3(-20, 4, -14),
			Vector3.ZERO, Vector3(2.2, 0.8, 0.5))
		_fish.append(f)
