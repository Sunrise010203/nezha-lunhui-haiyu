extends Node3D
## 第一章 · 东海 碎潮回廊
## 程序化构建：环境 → 地形 → 装饰 → 敌人 → 封印门 → Boss → 归途之门

const KILL_Y := -6.5

var player: Player
var cam: PlayerCamera
var hud: HUD
var checkpoint_pos := Vector3(0, 0.6, 0)
var boss: BossMaw
var boss_gate: Node3D = null
var boss_started := false
var arena1_enemies: Array[EnemyBase] = []
var arena1_gate: Node3D
var arena1_done := false
var _floaters: Array[Dictionary] = []
var _checkpoints: Array[Dictionary] = []
var _t := 0.0
var _env: Environment
var _sun: DirectionalLight3D
var _whale: Node3D
var _whale_tail: Node3D
var _whale_seed := 0.0
var _fish: Array[MeshInstance3D] = []

# 分区氛围：[x, 雾色, 环境光色, 体积雾反照率]
var _zone_stops: Array = [
	[0.0, Color(0.05, 0.16, 0.2), Color(0.25, 0.4, 0.45),
		Color(0.3, 0.6, 0.65)],
	[75.0, Color(0.045, 0.115, 0.225), Color(0.23, 0.33, 0.5),
		Color(0.3, 0.45, 0.7)],
	[112.0, Color(0.08, 0.07, 0.2), Color(0.33, 0.25, 0.46),
		Color(0.45, 0.3, 0.68)],
	[150.0, Color(0.115, 0.045, 0.13), Color(0.42, 0.22, 0.33),
		Color(0.6, 0.25, 0.42)],
]

# 共享材质
var mat_stone: StandardMaterial3D
var mat_stone_dark: StandardMaterial3D
var mat_trim: StandardMaterial3D
var mat_coral: StandardMaterial3D
var mat_crystal_c: StandardMaterial3D
var mat_crystal_p: StandardMaterial3D
var mat_gold: StandardMaterial3D
var mat_rune_c: StandardMaterial3D
var mat_rune_g: StandardMaterial3D


func _ready() -> void:
	Game.start_ambient()
	Game.play_theme(false)
	Game.run_active = true
	Game.souls = 0
	_make_materials()
	_build_environment()
	_build_water()
	_build_player_and_camera()
	_build_hud()
	_build_terrain()
	_build_decor()
	_build_enemies_and_logic()
	_build_boss_arena()
	hud.show_message("第一章 · 东海 碎潮回廊", 2.8, 60)


func _make_materials() -> void:
	mat_stone = Game.std_mat(Color(0.16, 0.24, 0.3), Color(0.01, 0.03, 0.04),
		0.4, 0.85)
	mat_stone_dark = Game.std_mat(Color(0.09, 0.13, 0.18),
		Color(0.005, 0.015, 0.02), 0.3, 0.9)
	mat_trim = Game.std_mat(Color(0.25, 0.75, 0.75), Color(0.2, 0.7, 0.7),
		1.3, 0.4)
	mat_coral = Game.std_mat(Color(0.7, 0.3, 0.4), Color(0.5, 0.15, 0.25),
		0.5, 0.6)
	mat_crystal_c = Game.std_mat(Color(0.3, 0.85, 0.85, 0.9),
		Color(0.2, 0.8, 0.8), 1.8, 0.2)
	mat_crystal_p = Game.std_mat(Color(0.6, 0.35, 0.9, 0.9),
		Color(0.55, 0.25, 0.85), 1.8, 0.2)
	mat_gold = Game.std_mat(Color(0.85, 0.68, 0.3), Color(0.6, 0.4, 0.1),
		0.6, 0.35, 0.85)
	mat_rune_c = Game.std_mat(Color(0.2, 0.45, 0.5), Color(0.15, 0.5, 0.5),
		0.55, 0.6)
	mat_rune_g = Game.std_mat(Color(0.5, 0.4, 0.2), Color(0.55, 0.38, 0.12),
		0.5, 0.6)
	# AI 石材纹理（三向贴图，世界坐标平铺）
	var stone_tex := Game.tex("res://art/stone.png")
	if stone_tex:
		for m: StandardMaterial3D in [mat_stone, mat_stone_dark]:
			m.albedo_texture = stone_tex
			m.uv1_triplanar = true
			m.uv1_scale = Vector3(0.13, 0.13, 0.13)
		mat_stone.albedo_color = Color(0.75, 0.88, 0.95)
		mat_stone_dark.albedo_color = Color(0.38, 0.48, 0.58)


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
	env.ambient_light_color = Color(0.25, 0.4, 0.45)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_strength = 1.0
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 0.9
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.16, 0.2)
	env.fog_density = 0.012
	env.fog_sky_affect = 0.15
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.022
	env.volumetric_fog_albedo = Color(0.3, 0.6, 0.65)
	env.volumetric_fog_emission = Color(0.01, 0.04, 0.05)
	env.volumetric_fog_emission_energy = 0.3
	env.volumetric_fog_anisotropy = 0.55
	env.volumetric_fog_length = 90.0
	env.volumetric_fog_ambient_inject = 0.4
	# 色彩校正：略提对比与饱和
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.14
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	_env = env

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(0.75, 0.95, 1.0)
	sun.light_energy = 1.1
	sun.light_volumetric_fog_energy = 1.4
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-48, 28, 0)
	add_child(sun)
	_sun = sun

	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.3, 0.2, 0.5)
	fill.light_energy = 0.35
	fill.rotation_degrees = Vector3(-20, -140, 0)
	add_child(fill)


func _build_water() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(700, 140)
	plane.subdivide_width = 160
	plane.subdivide_depth = 32
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/water.gdshader")
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = mat
	mi.position = Vector3(80, -7.0, -20)
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

	# 周围漂浮的灵尘
	for cx in [25.0, 80.0, 145.0]:
		var p := GPUParticles3D.new()
		p.amount = 70
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
	hud.bind_player(player)
	hud.respawn_callback = _respawn_full
	hud.restart_callback = func() -> void:
		Game.change_scene("res://scenes/level_1.tscn")


# ================================================================ 地形

func _platform(x0: float, x1: float, ytop: float, deep := 9.0,
		dark := false) -> StaticBody3D:
	var w := x1 - x0
	var cx := (x0 + x1) / 2.0
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = Vector3(cx, ytop - deep / 2.0, 0)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(w, deep, 6.0)
	col.shape = shape
	body.add_child(col)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(w, deep, 6.0)
	Game.add_mesh(body, mesh, mat_stone_dark if dark else mat_stone,
		Vector3.ZERO)
	# 顶面亮边（朝向镜头）
	var trim := BoxMesh.new()
	trim.size = Vector3(w, 0.08, 0.12)
	Game.add_mesh(body, trim, mat_trim, Vector3(0, deep / 2.0 - 0.02, 3.0))
	# 顶面散落的发光符文砖
	var tile := BoxMesh.new()
	tile.size = Vector3(0.75, 0.045, 0.75)
	for i in maxi(int(w / 5.0), 1):
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
	shape.size = Vector3(w, 0.8, 4.5)
	col.shape = shape
	body.add_child(col)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(w, 0.8, 4.5)
	Game.add_mesh(body, mesh, mat_stone, Vector3.ZERO)
	var trim := BoxMesh.new()
	trim.size = Vector3(w, 0.07, 0.12)
	Game.add_mesh(body, trim, mat_trim, Vector3(0, 0.38, 2.25))
	# 底部垂石
	var tip := CylinderMesh.new()
	tip.top_radius = w * 0.32
	tip.bottom_radius = 0.05
	tip.height = 1.6
	Game.add_mesh(body, tip, mat_stone_dark, Vector3(0, -1.2, 0))
	add_child(body)
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


func _build_terrain() -> void:
	# A 起点台地
	_platform(-8, 16, 0)
	_add_checkpoint(Vector3(0, 0, 0), true)
	_hint("A / D 移动　·　空格 跳跃（二段跳）", Vector3(3, 2.2, -2))
	_hint("Shift 冲刺 —— 瞬身无敌", Vector3(13.5, 2.4, -2))
	# 高处龙魂残片 1（二段跳可达）
	_float_platform(10, 4.4, 2.2)
	_add_pickup(Vector3(10, 5.5, 0), Pickup.Kind.SOUL)
	# B
	_platform(19.5, 30, 0.5)
	_hint("J 连击　·　K 重击　·　空中 K 下砸", Vector3(22, 2.8, -2))
	_hint("E 掷出乾坤圈（耗 25 灵力）", Vector3(28, 3.0, -2))
	# 小浮台
	_float_platform(33, 1.8, 2.6)
	# C 封印竞技场
	_platform(36.5, 53, 1)
	_hint("斩除异化之物，封印自解", Vector3(40, 3.6, -2))
	# D 上升浮台
	_float_platform(56, 2.8, 3.0)
	_float_platform(60, 4.2, 3.0)
	_float_platform(64, 5.6, 3.2)
	# E 高台
	_platform(66.5, 86, 6)
	_spikes(78.5, 81.5, 6)
	_add_checkpoint(Vector3(69, 6, 0), false)
	_add_pickup(Vector3(74, 7.0, 0), Pickup.Kind.HEAL)
	# 碎裂浮桥
	for i in 4:
		var fp := FallingPlatform.new()
		fp.width = 2.4
		fp.position = Vector3(88.5 + i * 3.1, 5.75, 0)
		add_child(fp)
	_hint("浮桥已被归墟侵蚀……勿要停留", Vector3(87, 8.2, -2))
	# 龙魂残片 2：碎裂浮桥上空（从浮桥二段跳取得）
	_add_pickup(Vector3(94.5, 8.6, 0), Pickup.Kind.SOUL)
	# F 试炼长廊
	_platform(100.5, 122, 6)
	_hint("灵力足够时按 Q —— 三昧真火", Vector3(104, 8.6, -2))
	_add_pickup(Vector3(112, 7.2, 0), Pickup.Kind.ENERGY)
	_add_pickup(Vector3(113.2, 7.4, 0), Pickup.Kind.ENERGY)
	# 下行阶梯
	_float_platform(124.5, 4.6, 2.8)
	_float_platform(127.5, 3.2, 2.8)
	# G Boss 竞技场
	_platform(130, 164, 2)
	_add_checkpoint(Vector3(128.0, 3.4, 0), false, true)
	_hint("前方灵气紊乱……深渊在注视你", Vector3(133, 4.8, -2))
	_add_pickup(Vector3(161.5, 3.2, 0), Pickup.Kind.HEAL)
	# 龙魂残片 3：Boss 场地右上高处
	_add_pickup(Vector3(162.0, 6.4, 0), Pickup.Kind.SOUL)
	# 场地两端隐形墙：防止 Boss 战中被击退坠台
	_invisible_wall(164.3, 2.0, 12.0)
	_invisible_wall(-8.3, 0.0, 12.0)


# ================================================================ 装饰

func _build_decor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	# AI 远景全景画：龙宫废墟剪影（两段拼接，第二段镜像）
	var bd := Game.tex("res://art/backdrop.png")
	if bd:
		for i in 2:
			var quad := QuadMesh.new()
			quad.size = Vector2(118, 50.6)
			var m := StandardMaterial3D.new()
			m.albedo_texture = bd
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
			if i == 1:
				m.uv1_scale = Vector3(-1, 1, 1)
			Game.add_mesh(self, quad, m, Vector3(28.0 + i * 117.0, 13.0, -52.0))
	# 背景断柱长廊
	for i in 26:
		var x := -10.0 + i * 7.0 + rng.randf_range(-2.0, 2.0)
		var z := rng.randf_range(-26.0, -9.0)
		_decor_pillar(x, z, rng)
	# 背景巨环（龙宫遗构）
	_decor_great_ring(45, -30, 9.0, mat_gold)
	_decor_great_ring(110, -34, 12.0, mat_trim)
	# 水晶
	var crystal_spots: Array = [
		[-5.0, 0.0, 1.6], [10.0, 0.0, -1.8], [27.0, 0.5, 1.8],
		[50.0, 1.0, -1.7], [70.0, 6.0, 1.9], [84.0, 6.0, -1.6],
		[108.0, 6.0, 1.7], [119.0, 6.0, -1.8], [136.0, 2.0, 1.8],
		[158.0, 2.0, -1.6],
	]
	for i in crystal_spots.size():
		var s: Array = crystal_spots[i]
		_decor_crystal(Vector3(s[0], s[1], s[2]), i % 2 == 0, rng, i % 3 == 0)
	# 海草
	for i in 30:
		var x := rng.randf_range(-8.0, 160.0)
		var z := rng.randf_range(-7.0, -3.5)
		_decor_kelp(x, z, rng)
	# 漂浮残岩
	for i in 12:
		var x := rng.randf_range(0.0, 160.0)
		var y := rng.randf_range(8.0, 14.0)
		var z := rng.randf_range(-18.0, -6.0)
		_decor_float_rock(Vector3(x, y, z), rng)
	# 残灯
	for x in [8.0, 44.0, 76.0, 116.0, 146.0]:
		_decor_lantern(Vector3(x, 5.5 + sin(x) * 1.5, -4.0))
	# 归墟巨涡（Boss 背景）
	_decor_vortex(Vector3(150, 6, -24))
	# 背景游弋的生灵
	_build_whale()
	_build_fish_school()
	# 渊晶瓮（可击碎）
	var urns: Array = [
		[12.0, 0.0, false], [24.5, 0.5, false], [42.0, 1.0, false],
		[50.5, 1.0, true], [71.5, 6.0, false], [85.0, 6.0, false],
		[103.5, 6.0, false], [118.5, 6.0, true], [140.0, 2.0, false],
		[160.0, 2.0, false],
	]
	for u: Array in urns:
		var b := Breakable.new()
		b.drop_heal = u[2]
		b.position = Vector3(u[0], u[1], 0.8)
		add_child(b)


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
	# 头部圆润
	var head := SphereMesh.new()
	head.radius = 0.95
	head.height = 1.9
	Game.add_mesh(_whale, head, dark, Vector3(2.2, 0.1, 0),
		Vector3.ZERO, Vector3(1.4, 1.0, 0.9))
	# 胸鳍
	var fin := SphereMesh.new()
	fin.radius = 0.7
	fin.height = 1.4
	Game.add_mesh(_whale, fin, dark, Vector3(0.8, -0.7, 0.5),
		Vector3(20, 0, -30), Vector3(1.2, 0.18, 0.5))
	Game.add_mesh(_whale, fin, dark, Vector3(0.8, -0.7, -0.5),
		Vector3(-20, 0, -30), Vector3(1.2, 0.18, 0.5))
	# 尾部（独立节点摆动）
	_whale_tail = Node3D.new()
	_whale_tail.position = Vector3(-3.2, 0.1, 0)
	_whale.add_child(_whale_tail)
	Game.add_mesh(_whale_tail, fin, dark, Vector3(-0.8, 0, 0),
		Vector3.ZERO, Vector3(1.1, 0.25, 1.9))
	# 背部发光斑点（渊海生灵的微光）
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
	## 中景鱼群
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


func _decor_pillar(x: float, z: float, rng: RandomNumberGenerator) -> void:
	var h := rng.randf_range(6.0, 14.0)
	var holder := Node3D.new()
	holder.position = Vector3(x, -4.0, z)
	holder.rotation_degrees = Vector3(rng.randf_range(-6, 6), 0,
		rng.randf_range(-7, 7))
	add_child(holder)
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.7
	cyl.bottom_radius = 0.9
	cyl.height = h
	Game.add_mesh(holder, cyl, mat_stone_dark, Vector3(0, h / 2.0, 0))
	if rng.randf() < 0.6:
		var cap := BoxMesh.new()
		cap.size = Vector3(2.2, 0.5, 2.2)
		Game.add_mesh(holder, cap, mat_stone_dark, Vector3(0, h + 0.25, 0),
			Vector3(0, rng.randf_range(0, 45), 0))


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
	var holder := Node3D.new()
	holder.position = pos
	add_child(holder)
	var mat := mat_crystal_c if cyan else mat_crystal_p
	for i in rng.randi_range(2, 4):
		var prism := PrismMesh.new()
		var s := rng.randf_range(0.25, 0.7)
		prism.size = Vector3(s, s * rng.randf_range(2.0, 3.5), s)
		Game.add_mesh(holder, prism, mat,
			Vector3(rng.randf_range(-0.5, 0.5), prism.size.y * 0.35,
				rng.randf_range(-0.3, 0.3)),
			Vector3(rng.randf_range(-18, 18), rng.randf_range(0, 360),
				rng.randf_range(-18, 18)))
	if with_light:
		var light := OmniLight3D.new()
		light.light_color = Color(0.3, 0.85, 0.85) if cyan \
			else Color(0.6, 0.35, 0.9)
		light.light_energy = 1.6
		light.omni_range = 5.0
		light.position = Vector3(0, 0.8, 0)
		light.shadow_enabled = false
		holder.add_child(light)


func _decor_kelp(x: float, z: float, rng: RandomNumberGenerator) -> void:
	var mat := Game.std_mat(Color(0.1, 0.35, 0.3), Color(0.05, 0.25, 0.2),
		0.4, 0.7)
	var holder := Node3D.new()
	holder.position = Vector3(x, -6.5, z)
	add_child(holder)
	for i in rng.randi_range(2, 4):
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.02
		cyl.bottom_radius = 0.07
		cyl.height = rng.randf_range(2.0, 5.0)
		var k := Game.add_mesh(holder, cyl, mat,
			Vector3(rng.randf_range(-0.6, 0.6), cyl.height / 2.0,
				rng.randf_range(-0.4, 0.4)),
			Vector3(rng.randf_range(-10, 10), 0, rng.randf_range(-10, 10)))
		_floaters.append({"node": k, "speed": rng.randf_range(0.3, 0.7),
			"axis": "sway", "base": k.rotation.z})


func _decor_float_rock(pos: Vector3, rng: RandomNumberGenerator) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = rng.randf_range(0.5, 1.4)
	mesh.height = mesh.radius * 1.4
	mesh.radial_segments = 8
	mesh.rings = 5
	var mi := Game.add_mesh(self, mesh, mat_stone_dark, pos,
		Vector3(rng.randf_range(0, 360), rng.randf_range(0, 360), 0))
	_floaters.append({"node": mi, "speed": rng.randf_range(0.1, 0.3),
		"axis": "y", "bob": rng.randf_range(0.3, 0.8),
		"base_y": pos.y, "phase": rng.randf() * TAU})


func _decor_lantern(pos: Vector3) -> void:
	var holder := Node3D.new()
	holder.position = pos
	add_child(holder)
	var shell := SphereMesh.new()
	shell.radius = 0.3
	shell.height = 0.6
	var mat := Game.std_mat(Color(0.95, 0.7, 0.35, 0.85),
		Color(1.0, 0.65, 0.25), 1.6, 0.4)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	Game.add_mesh(holder, shell, mat, Vector3.ZERO,
		Vector3.ZERO, Vector3(1, 1.25, 1))
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.65, 0.3)
	light.light_energy = 1.2
	light.omni_range = 6.0
	light.shadow_enabled = false
	holder.add_child(light)
	_floaters.append({"node": holder, "speed": 0.5, "axis": "y", "bob": 0.4,
		"base_y": pos.y, "phase": randf() * TAU})


func _decor_vortex(pos: Vector3) -> void:
	## 归墟巨涡：Boss 区背景中缓缓旋转的深渊之眼
	var holder := Node3D.new()
	holder.position = pos
	add_child(holder)
	# AI 漩涡画（黑底加法混合，缓缓旋转）
	var vt := Game.tex("res://art/vortex.png")
	if vt:
		var quad := QuadMesh.new()
		quad.size = Vector2(26, 26)
		var vm := StandardMaterial3D.new()
		vm.albedo_texture = vt
		vm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		vm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		vm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		vm.disable_receive_shadows = true
		var vq := Game.add_mesh(holder, quad, vm, Vector3(0, 0, -1.5))
		_floaters.append({"node": vq, "speed": 0.12, "axis": "spin_z"})
	for i in 3:
		var torus := TorusMesh.new()
		torus.inner_radius = 3.0 + i * 2.2
		torus.outer_radius = 3.5 + i * 2.2
		var c := Color(0.4 - i * 0.1, 0.15, 0.6 - i * 0.12)
		var mat := Game.std_mat(c, c, 1.2 - i * 0.3, 0.5)
		var mi := Game.add_mesh(holder, torus, mat, Vector3.ZERO,
			Vector3(90, 0, 0))
		_floaters.append({"node": mi, "speed": 0.3 - i * 0.08, "axis": "z"})
	var core := SphereMesh.new()
	core.radius = 2.2
	core.height = 4.4
	Game.add_mesh(holder, core, Game.std_mat(Color(0.04, 0.01, 0.08),
		Color(0.15, 0.02, 0.25), 0.8, 0.6), Vector3.ZERO)


func _hint(text: String, pos: Vector3) -> void:
	var lbl := Label3D.new()
	lbl.text = text
	lbl.font = Game.world_font
	lbl.font_size = 40
	lbl.outline_size = 10
	lbl.outline_modulate = Color(0, 0.05, 0.08, 0.8)
	lbl.modulate = Color(0.65, 0.9, 0.9, 0.85)
	lbl.pixel_size = 0.01
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.position = pos
	add_child(lbl)


# ================================================================ 互动物件

func _add_pickup(pos: Vector3, kind: Pickup.Kind) -> void:
	var p := Pickup.new()
	p.kind = kind
	p.position = pos
	add_child(p)


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
	light.position = Vector3(0, 1.2, 0)
	light.shadow_enabled = false
	holder.add_child(light)

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
	area.body_entered.connect(func(b: Node3D) -> void:
		if b is Player:
			_activate_checkpoint(idx))
	if start_active:
		light.light_energy = 1.5


func _activate_checkpoint(idx: int) -> void:
	var cp: Dictionary = _checkpoints[idx]
	checkpoint_pos = cp["pos"]
	if cp["active"]:
		return
	cp["active"] = true
	player.heal(player.MAX_HP)
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
	shape.size = Vector3(0.7, h, 6.0)
	col.shape = shape
	gate.add_child(col)
	var frame := BoxMesh.new()
	frame.size = Vector3(0.7, h, 5.0)
	var seal_mat := Game.std_mat(Color(0.4, 0.2, 0.7, 0.55),
		Color(0.5, 0.25, 0.9), 1.5, 0.3)
	seal_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	Game.add_mesh(gate, frame, seal_mat, Vector3.ZERO)
	# 两侧石柱
	var pillar := CylinderMesh.new()
	pillar.top_radius = 0.35
	pillar.bottom_radius = 0.45
	pillar.height = h + 1.0
	Game.add_mesh(gate, pillar, mat_stone_dark, Vector3(0, 0, 2.6))
	Game.add_mesh(gate, pillar, mat_stone_dark, Vector3(0, 0, -2.6))
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
	Game.burst(self, gate.global_position, Color(0.7, 0.4, 1.0), 30, 6.0,
		0.09, 0.8)
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


# ================================================================ 敌人与关卡逻辑

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


func _build_enemies_and_logic() -> void:
	# B 段首个爬行者
	_spawn_crawler(25, 1.0, 20.5, 29.0)
	# C 封印竞技场
	arena1_gate = _make_gate(52.5, 1.0)
	_add_trigger(40, 2.5, 3.0, 4.0, _start_arena1)
	# D 段悬浮射手
	_spawn_shooter(61, 7.0, 56.0, 65.0)
	# E 段
	_spawn_crawler(76, 7.0, 71.0, 77.5)
	_spawn_crawler(83, 7.0, 82.0, 85.5)
	# F 试炼长廊
	_spawn_crawler(106, 7.0, 101.5, 112.0)
	_spawn_shooter(110, 9.5, 103.0, 118.0)
	_spawn_crawler(115, 7.0, 109.0, 120.5)
	_spawn_shooter(117, 9.0, 110.0, 120.5)


func _start_arena1() -> void:
	hud.show_message("封印结界 · 斩除异化之物", 2.0, 42)
	Game.play_sfx("roar", -10.0, 1.6)
	var spawns := [
		_spawn_crawler(44, 2.0, 38.0, 51.5),
		_spawn_crawler(48, 2.0, 38.0, 51.5),
		_spawn_shooter(46, 4.5, 39.0, 51.0),
	]
	for e: EnemyBase in spawns:
		arena1_enemies.append(e)
		Game.burst(self, e.global_position, Color(0.5, 0.25, 0.8), 20, 5.0,
			0.08, 0.6)
		e.enemy_died.connect(_on_arena1_death)


func _on_arena1_death(_e: EnemyBase) -> void:
	if arena1_done:
		return
	for e in arena1_enemies:
		if is_instance_valid(e) and not e.dead:
			return
	arena1_done = true
	hud.show_message("封 印 已 解", 2.0, 48)
	_open_gate(arena1_gate)


# ================================================================ Boss

func _build_boss_arena() -> void:
	boss = BossMaw.new()
	boss.position = Vector3(150, 6.2, 0)
	boss.arena_min_x = 131.5
	boss.arena_max_x = 163.0
	boss.ground_y = 2.0
	add_child(boss)
	boss.boss_hp_changed.connect(hud.on_boss_hp)
	boss.summon_requested.connect(_on_boss_summon)
	boss.boss_defeated.connect(_on_boss_defeated)
	_add_trigger(137, 4.0, 3.0, 5.0, _start_boss)


func _start_boss() -> void:
	if boss_started or boss.dead:
		return
	boss_started = true
	boss_gate = _make_gate(132.5, 2.0, 7.0)
	Game.burst(self, Vector3(132.5, 5, 0), Color(0.7, 0.4, 1.0), 30, 6.0,
		0.1, 0.7)
	hud.show_message("归墟之喉 · 渊狱兽", 2.4, 56)
	hud.show_boss_bar(true)
	boss.activate()


func _on_boss_summon(count: int) -> void:
	hud.show_message("深渊的爪牙涌出……", 1.5, 36)
	for i in count:
		var x := 138.0 + i * 18.0
		var e := _spawn_crawler(x, 3.0, 133.5, 161.0)
		Game.burst(self, e.global_position, Color(0.5, 0.25, 0.8), 20, 5.0,
			0.08, 0.6)


func _on_boss_defeated() -> void:
	hud.show_boss_bar(false)
	Game.run_active = false
	if boss_gate:
		_open_gate(boss_gate)
		boss_gate = null
	hud.show_message("渊 兽 已 被 镇 压", 2.6, 56)
	await get_tree().create_timer(1.8, false).timeout
	_spawn_portal()


func _spawn_portal() -> void:
	var holder := Node3D.new()
	holder.position = Vector3(152, 4.2, 0)
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
	holder.add_child(light)
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
	hud.show_message("秩序回响之门已开启", 2.2, 40)

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
			hud.show_victory())


# ================================================================ 生死循环

func _on_player_died() -> void:
	hud.show_death()


func _reset_boss_fight() -> void:
	## Boss 战中阵亡或坠渊：完整重置 Boss、封门与触发器
	if not boss_started or not is_instance_valid(boss) or boss.dead:
		return
	boss.reset_fight()
	boss_started = false
	hud.show_boss_bar(false)
	if boss_gate and is_instance_valid(boss_gate):
		boss_gate.queue_free()
		boss_gate = null
	# 重新武装触发器
	_add_trigger(137, 4.0, 3.0, 5.0, _start_boss)
	hud.show_message("渊狱兽沉回了深处……", 1.6, 34)


func _respawn_full() -> void:
	Game.flash_fade(0.5)
	await get_tree().create_timer(0.25, false).timeout
	_reset_boss_fight()
	player.respawn(checkpoint_pos)
	cam.snap_to_target()


func _physics_process(_delta: float) -> void:
	if player.act == "dead":
		return
	if player.global_position.y < KILL_Y:
		# 坠渊：受伤并拉回莲台
		player.take_damage(15.0, player.global_position.x + 1.0)
		if player.act != "dead":
			_reset_boss_fight()
			Game.flash_fade(0.4)
			player.global_position = checkpoint_pos
			player.velocity = Vector3.ZERO
			player.invuln = maxf(player.invuln, 1.0)
			cam.snap_to_target()


func _process(delta: float) -> void:
	_t += delta
	_update_zone_ambience(delta)
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


func _update_zone_ambience(delta: float) -> void:
	## 随玩家深入，雾色与环境光从月光青渐变到深渊红紫
	if player == null or not is_instance_valid(player):
		return
	var x := player.global_position.x
	var fog: Color = _zone_stops[0][1]
	var amb: Color = _zone_stops[0][2]
	var va: Color = _zone_stops[0][3]
	for i in _zone_stops.size() - 1:
		var a: Array = _zone_stops[i]
		var b: Array = _zone_stops[i + 1]
		if x >= a[0]:
			var t := clampf((x - a[0]) / (b[0] - a[0]), 0.0, 1.0)
			t = t * t * (3.0 - 2.0 * t)
			fog = (a[1] as Color).lerp(b[1], t)
			amb = (a[2] as Color).lerp(b[2], t)
			va = (a[3] as Color).lerp(b[3], t)
	# 平滑过渡，避免突变
	var k := clampf(2.5 * delta, 0.0, 1.0)
	_env.fog_light_color = _env.fog_light_color.lerp(fog, k)
	_env.ambient_light_color = _env.ambient_light_color.lerp(amb, k)
	_env.volumetric_fog_albedo = _env.volumetric_fog_albedo.lerp(va, k)
	var sun_c := Color(0.75, 0.95, 1.0).lerp(Color(0.95, 0.62, 0.6),
		clampf(x / 150.0, 0.0, 1.0))
	_sun.light_color = _sun.light_color.lerp(sun_c, k)


func _update_wildlife(delta: float) -> void:
	## 巨鲸横穿 + 鱼群游弋
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
		var anchor := Vector3(fposmod(_t * 5.5 + i * 0.0, 230.0) - 25.0,
			5.0 + sin(_t * 0.6) * 1.6, -13.5)
		f.position = anchor + Vector3(sin(_t * 2.0 + i * 1.3) * 1.4 +
			(i % 3) * 0.7, cos(_t * 1.7 + i * 0.9) * 0.8,
			sin(_t * 1.2 + i * 0.6) * 0.6)
		f.rotation.z = cos(_t * 2.0 + i * 1.3) * 0.2
