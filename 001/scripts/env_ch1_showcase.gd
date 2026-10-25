extends Node3D
# 第一章「东海·碎潮回廊」场景复刻 v7
# v7：灯笼 / 走道 / 柱子改为可复用「环境资产」（程序化模块化），去掉占位发光盒
# 坐标：相机 z=12 fov=36 → 可视 13.87x7.80m，中心 y=1.95；u,v 为参考图归一化坐标

const OUT := "user://env_shots"
const GLB := "res://art/models/glb_game"
const REF := "res://art/ref/ch1_corridor.png"
const VIEW_W := 13.867
const VIEW_H := 7.8
const VIEW_CY := 1.95
const WALK_V := 0.715

var cam: Camera3D
var mat_stone: StandardMaterial3D
var mat_dark: StandardMaterial3D
var mat_darkstone: StandardMaterial3D
var mat_bronze: StandardMaterial3D


func wx(u: float) -> float: return (u - 0.5) * VIEW_W
func wy(v: float) -> float: return VIEW_CY - (v - 0.5) * VIEW_H


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_build_materials()
	_build_env()
	cam = Camera3D.new()
	cam.fov = 36.0
	var attrs := CameraAttributesPractical.new()
	attrs.dof_blur_far_enabled = true
	attrs.dof_blur_far_distance = 42.0
	attrs.dof_blur_far_transition = 26.0
	attrs.dof_blur_amount = 0.06
	cam.attributes = attrs
	add_child(cam)
	cam.current = true
	cam.position = Vector3(0, VIEW_CY, 12.0)
	cam.look_at(Vector3(0, VIEW_CY, 0), Vector3.UP)

	_build_backdrop()
	_build_platform()
	_build_pillars()
	_build_props()
	_build_dust()
	for cl in get_tree().root.find_children("*", "CanvasLayer", true, false):
		cl.visible = false
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + "/env_ch1_showcase.png")
	print("SHOT env_ch1_showcase")
	get_tree().quit()


# ---------------- 材质 ----------------
func _noise(seed_v: int, freq: float, as_normal := false, bump := 6.0) -> NoiseTexture2D:
	var nt := NoiseTexture2D.new()
	var n := FastNoiseLite.new()
	n.seed = seed_v
	n.frequency = freq
	n.fractal_octaves = 4
	nt.noise = n
	nt.seamless = true
	nt.width = 512
	nt.height = 512
	nt.as_normal_map = as_normal
	nt.bump_strength = bump
	return nt


func _stone(col: Color, rough: float, uv_scale := 0.55) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.albedo_texture = _noise(7, 0.02)
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(uv_scale, uv_scale, uv_scale)
	m.normal_enabled = true
	m.normal_texture = _noise(21, 0.05, true, 5.0)
	m.normal_scale = 0.8
	m.roughness_texture = _noise(33, 0.03)
	return m


func _build_materials() -> void:
	mat_stone = _stone(Color(0.16, 0.21, 0.21), 0.84)
	mat_dark = _stone(Color(0.06, 0.09, 0.095), 0.93)
	mat_darkstone = _stone(Color(0.10, 0.14, 0.145), 0.88)
	mat_bronze = StandardMaterial3D.new()
	mat_bronze.albedo_color = Color(0.36, 0.30, 0.16)
	mat_bronze.metallic = 0.85
	mat_bronze.roughness = 0.42


# 把 Tripo 自带的材质整体压暗（保留贴图），让资产融入深海色调
func _tint(root: Node3D, mul: float) -> void:
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var src: StandardMaterial3D = null
		if mi.material_override is StandardMaterial3D:
			src = mi.material_override
		elif mi.get_surface_override_material(0) is StandardMaterial3D:
			src = mi.get_surface_override_material(0)
		elif mi.mesh != null and mi.mesh.get_surface_count() > 0:
			var m = mi.mesh.surface_get_material(0)
			if m is StandardMaterial3D:
				src = m
		if src == null:
			continue
		var m2: StandardMaterial3D = src.duplicate()
		var c: Color = m2.albedo_color
		m2.albedo_color = Color(c.r * mul, c.g * mul, c.b * mul, c.a)
		m2.roughness = min(1.0, m2.roughness + 0.12)
		mi.material_override = m2


# ---------------- 环境 ----------------
func _build_env() -> void:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.008, 0.035, 0.045)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.26, 0.55, 0.64)
	e.ambient_light_energy = 0.42
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 1.05
	e.glow_enabled = true
	e.glow_intensity = 0.45
	e.glow_bloom = 0.12
	e.glow_hdr_threshold = 1.1
	e.fog_enabled = true
	e.fog_light_color = Color(0.06, 0.28, 0.34)
	e.fog_light_energy = 0.40
	e.fog_density = 0.008
	e.fog_aerial_perspective = 0.2
	e.volumetric_fog_enabled = true
	e.volumetric_fog_density = 0.006
	e.volumetric_fog_albedo = Color(0.42, 0.78, 0.86)
	e.volumetric_fog_emission = Color(0.015, 0.08, 0.10)
	e.volumetric_fog_length = 55.0
	e.volumetric_fog_anisotropy = 0.4
	e.ssao_enabled = true
	e.ssao_intensity = 2.0
	e.ssil_enabled = true
	e.ssr_enabled = true
	e.ssr_max_steps = 80
	e.adjustment_enabled = true
	e.adjustment_contrast = 1.08
	e.adjustment_saturation = 1.04
	we.environment = e
	add_child(we)

	var key := DirectionalLight3D.new()
	key.light_color = Color(0.80, 0.97, 1.0)
	key.light_energy = 1.25
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 60.0
	add_child(key)
	key.rotation_degrees = Vector3(-62, -18, 0)

	var rim := DirectionalLight3D.new()
	rim.light_color = Color(0.35, 0.85, 0.95)
	rim.light_energy = 0.5
	add_child(rim)
	rim.rotation_degrees = Vector3(-18, 160, 0)

	for s in [[-1.8, -9.0, 0.45], [2.8, -12.0, 0.3]]:
		var sp := SpotLight3D.new()
		sp.light_color = Color(0.72, 0.98, 1.0)
		sp.light_energy = 9.0
		sp.spot_range = 44.0
		sp.spot_angle = 13.0
		sp.spot_attenuation = 1.1
		sp.light_volumetric_fog_energy = 2.6
		sp.position = Vector3(s[0], 17.0, s[1])
		add_child(sp)
		sp.rotation_degrees = Vector3(-90, 0, 0)


func _build_backdrop() -> void:
	var tex := ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(REF)))
	var q := QuadMesh.new()
	q.size = Vector2(54.0, 30.4)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.66, 0.74, 0.78)
	m.disable_fog = true
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mi.material_override = m
	mi.position = Vector3(0, VIEW_CY + 0.6, -32.0)
	add_child(mi)


# ---------------- 通用件 ----------------
func _mesh(mesh: Mesh, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	add_child(mi)
	return mi


func _box(sz: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = sz
	return _mesh(bm, pos, mat, rot)


func _cyl(rt: float, rb: float, h: float, pos: Vector3, mat: Material, seg := 24) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = rt
	cm.bottom_radius = rb
	cm.height = h
	cm.radial_segments = seg
	return _mesh(cm, pos, mat)


# ---------------- 环境资产 A：石灯笼 ----------------
func _lantern(pos: Vector3, s: float) -> void:
	var root := Node3D.new()
	root.position = pos
	root.scale = Vector3.ONE * s
	add_child(root)

	var base := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.62, 0.10, 0.62)
	base.mesh = bm
	base.material_override = mat_stone
	base.position = Vector3(0, 0.05, 0)
	root.add_child(base)

	var lotus := MeshInstance3D.new()
	var lm := CylinderMesh.new()
	lm.top_radius = 0.24
	lm.bottom_radius = 0.30
	lm.height = 0.12
	lotus.mesh = lm
	lotus.material_override = mat_stone
	lotus.position = Vector3(0, 0.16, 0)
	root.add_child(lotus)

	var shaft := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.20, 0.52, 0.20)
	shaft.mesh = sm
	shaft.material_override = mat_stone
	shaft.position = Vector3(0, 0.48, 0)
	root.add_child(shaft)

	var mid := MeshInstance3D.new()
	var mm := BoxMesh.new()
	mm.size = Vector3(0.46, 0.07, 0.46)
	mid.mesh = mm
	mid.material_override = mat_stone
	mid.position = Vector3(0, 0.77, 0)
	root.add_child(mid)

	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var post := MeshInstance3D.new()
			var pm := BoxMesh.new()
			pm.size = Vector3(0.055, 0.34, 0.055)
			post.mesh = pm
			post.material_override = mat_stone
			post.position = Vector3(sx * 0.17, 0.975, sz * 0.17)
			root.add_child(post)

	var core := MeshInstance3D.new()
	var cm2 := BoxMesh.new()
	cm2.size = Vector3(0.24, 0.26, 0.24)
	core.mesh = cm2
	var core_mat := StandardMaterial3D.new()
	core_mat.albedo_color = Color(1.0, 0.78, 0.42)
	core_mat.emission_enabled = true
	core_mat.emission = Color(1.0, 0.72, 0.34)
	core_mat.emission_energy_multiplier = 2.2
	core.material_override = core_mat
	core.position = Vector3(0, 0.975, 0)
	root.add_child(core)

	for i in 4:
		var pane := MeshInstance3D.new()
		var pm2 := BoxMesh.new()
		pm2.size = Vector3(0.30, 0.28, 0.02)
		pane.mesh = pm2
		pane.material_override = mat_bronze
		var ang := deg_to_rad(90 * i)
		pane.position = Vector3(sin(ang) * 0.165, 0.975, cos(ang) * 0.165)
		pane.rotation_degrees.y = rad_to_deg(ang)
		root.add_child(pane)

	var roof := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 0.03
	rm.bottom_radius = 0.46
	rm.height = 0.20
	rm.radial_segments = 4
	roof.mesh = rm
	roof.material_override = mat_stone
	roof.position = Vector3(0, 1.20, 0)
	roof.rotation_degrees.y = 45
	root.add_child(roof)

	var finial := MeshInstance3D.new()
	var fm := SphereMesh.new()
	fm.radius = 0.06
	fm.height = 0.14
	finial.mesh = fm
	finial.material_override = mat_bronze
	finial.position = Vector3(0, 1.34, 0)
	root.add_child(finial)

	var ol := OmniLight3D.new()
	ol.light_color = Color(1.0, 0.70, 0.34)
	ol.light_energy = 1.4
	ol.omni_range = 2.4
	ol.position = pos + Vector3(0, 0.98 * s, 0)
	ol.shadow_enabled = false
	add_child(ol)


# ---------------- 环境资产 B：走道模块 ----------------
func _walkway(x0: float, x1: float, top: float) -> void:
	var w: float = x1 - x0
	var cx: float = (x0 + x1) * 0.5
	_box(Vector3(w, 0.42, 2.7), Vector3(cx, top - 0.21, 0), mat_stone)
	_box(Vector3(w, 0.10, 2.86), Vector3(cx, top - 0.05, 0), mat_stone)
	_box(Vector3(w, 0.22, 2.74), Vector3(cx, top - 0.47, 0), mat_bronze)
	_box(Vector3(w, 0.62, 2.66), Vector3(cx, top - 0.89, 0), mat_dark)
	_box(Vector3(w, 0.12, 2.9), Vector3(cx, top - 1.25, 0), mat_stone)

	var rng := RandomNumberGenerator.new()
	rng.seed = int(abs(cx) * 97) + 11
	for i in int(w * 1.5):
		var rx := x0 + rng.randf() * w
		var s := rng.randf_range(0.07, 0.20)
		var rock := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(s * 1.6, s * 0.8, s * 1.2)
		rock.mesh = sm
		rock.material_override = mat_dark
		rock.position = Vector3(rx, top - 0.10, rng.randf_range(1.34, 1.52))
		rock.rotation_degrees = Vector3(rng.randf_range(-25, 25), rng.randf_range(0, 360), rng.randf_range(-25, 25))
		add_child(rock)


func _build_platform() -> void:
	var top := wy(WALK_V)
	var gl := wx(0.500)
	var gr := wx(0.548)
	_walkway(gl - 9.2, gl, top)
	_walkway(gr, gr + 8.8, top)

	# 断口：T21 踏步模块三级下沉
	for i in 3:
		var st := _spawn("T21_step.glb", gl + 0.34 + i * 0.34, -0.15, 0.48, top - 0.30 - i * 0.30, 0)
		if st != null:
			_tint(st, 0.45)

	# 玩法带（62%–82%）保持空地：走道面不放任何装饰件。
	# 装饰只出现在两侧画面边缘（u<0.10 / u>0.90），且压在走道前沿立面之下。
	_scatter("T23_rubble.glb", 2, gl - 9.2, gl - 8.2, top - 0.28, 1.35, 1.5, 0.30, 0.45, 0.55)
	_scatter("T23_rubble.glb", 2, gr + 7.9, gr + 8.8, top - 0.28, 1.35, 1.5, 0.30, 0.45, -0.55)
	_scatter("T24_barnacle.glb", 3, gl - 9.2, gl - 8.0, top - 0.45, 1.42, 1.55, 0.22, 0.32, 0.75)
	_scatter("T24_barnacle.glb", 3, gr + 7.9, gr + 8.8, top - 0.45, 1.42, 1.55, 0.22, 0.32, -0.75)

	var water := MeshInstance3D.new()
	var wp := PlaneMesh.new()
	wp.size = Vector2(90, 60)
	water.mesh = wp
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.010, 0.075, 0.10)
	wm.roughness = 0.05
	wm.metallic = 0.85
	wm.normal_enabled = true
	wm.normal_texture = _noise(55, 0.08, true, 2.0)
	wm.normal_scale = 0.35
	water.material_override = wm
	water.position = Vector3(0, top - 1.55, 4.0)
	add_child(water)


# ---------------- GLB 放置 ----------------
func _load_glb(path: String) -> Node3D:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	if doc.append_from_file(path, st) != OK:
		push_warning("load fail " + path)
		return null
	return doc.generate_scene(st)


func _aabb_of(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var w: AABB = mi.global_transform * mi.get_aabb()
		if first:
			out = w
			first = false
		else:
			out = out.merge(w)
	return out


func _spawn(file: String, x: float, z: float, h_target: float, base_y: float, rot_y := 0.0) -> Node3D:
	var n := _load_glb(GLB + "/" + file)
	if n == null:
		return null
	add_child(n)
	n.rotation_degrees.y = rot_y
	n.scale = Vector3.ONE
	var ab := _aabb_of(n)
	var s: float = h_target / max(ab.size.y, 0.001)
	n.scale = Vector3.ONE * s
	ab = _aabb_of(n)
	n.position = Vector3(x, base_y - ab.position.y, z)
	return n


# ---------------- 环境资产 C：柱子模块 ----------------
func _pillar_module(u: float, v_top: float, z: float, cap_h: float, r: float) -> void:
	var px := wx(u)
	var top := wy(v_top)
	# 柱子一律从走道面起算（略埋入），保证基座/莲座露在水面之上
	var bottom: float = wy(WALK_V) - 0.28
	var h: float = top - bottom
	if h <= 0.2:
		return
	var base_h: float = clamp(h * 0.34, 0.5, 2.4)
	var node := _load_glb(GLB + "/T17_pillar.glb")
	if node != null:
		add_child(node)
		node.scale = Vector3.ONE * (base_h / 0.98)
		node.rotation_degrees.y = 90.0 * float(int(u * 100) % 4)
		node.position = Vector3(px, bottom, z)
		_tint(node, 0.62)
	# 柱身：T18 柱身中段模块按直径缩放后堆叠（上下平口，可无缝接基座与柱头）
	var shaft_bottom: float = bottom + base_h - 0.22
	var shaft_h: float = (top - 0.04) - shaft_bottom
	if shaft_h > 0.05:
		var s: float = (r * 2.0) / 0.40
		var unit_h: float = 0.98 * s
		var n: int = max(1, int(ceil(shaft_h / unit_h)))
		for i in n:
			var seg := _load_glb(GLB + "/T18_shaft.glb")
			if seg == null:
				break
			add_child(seg)
			seg.scale = Vector3.ONE * s
			seg.rotation_degrees.y = 90.0 * float((i + int(u * 10)) % 4)
			seg.position = Vector3(px, (top - 0.04) - unit_h * float(n - i), z)
			_tint(seg, 0.60)
	# 柱头（Tripo T03）
	var cap := _spawn("3.glb", px, z, cap_h, top, 8 + u * 45)
	if cap != null:
		_tint(cap, 0.70)


func _build_pillars() -> void:
	# [u 屏幕位置, v 柱顶, z 景深, 柱头高, 柱半径]
	var defs := [
		[0.075, 0.30, -7.5, 1.15, 0.42],
		[0.215, 0.34, -6.0, 1.35, 0.44],
		[0.305, 0.53, -9.0, 1.00, 0.40],
		[0.437, 0.63, -12.0, 0.70, 0.36],
		[0.868, 0.08, -4.5, 1.80, 0.55],
	]
	for d in defs:
		_pillar_module(d[0], d[1], d[2], d[3], d[4])


# ---------------- 道具 ----------------
func _build_props() -> void:
	var top := wy(WALK_V)
	_spawn("001_1.glb", wx(0.745), -27.0, 3.0, wy(0.63), -14)
	_spawn("2.glb", wx(0.196), -1.15, 1.28, top, 12)
	_spawn("2.glb", wx(0.906), -1.15, 1.35, top, -24)
	# 石灯笼：用 Tripo 出的 T16 资产（母版高 0.98），按需等比放大到 ~1.9m
	_lantern_asset(wx(0.070), top, 1.05, 1.30, 6.0)
	_lantern_asset(wx(0.716), top, 1.1, 1.34, -10.0)
	# 中景拱券（T22）：放在断柱之间做纵深锚点
	var arch := _spawn("T22_arch.glb", wx(0.335), -10.5, 3.6, top - 0.1, 6.0)
	if arch != null:
		_tint(arch, 0.55)


# 一段栏杆：T19 按长度循环铺 + 两端 T20 望柱
func _railing(x0: float, x1: float, top: float, z: float) -> void:
	var seg_len: float = 1.75
	var n: int = max(1, int(round((x1 - x0) / seg_len)))
	var step: float = (x1 - x0) / float(n)
	for i in n:
		var seg := _spawn("T19_balustrade.glb", x0 + step * (float(i) + 0.5), z, 0.98, top, 90.0)
		if seg != null:
			_tint(seg, 0.62)
	for x in [x0, x1]:
		var post := _spawn("T20_post.glb", x, z, 1.15, top, 0.0)
		if post != null:
			_tint(post, 0.62)


# 在一条带子上随机撒 n 个资产实例
func _scatter(file: String, n: int, x0: float, x1: float, base_y: float,
		z_min: float, z_max: float, h_min: float, h_max: float, tint_mul: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(abs(x0 * 31.0 + x1 * 7.0)) + n
	for i in n:
		var x := rng.randf_range(x0, x1)
		var z := rng.randf_range(z_min, z_max)
		var h := rng.randf_range(h_min, h_max)
		var node := _spawn(file, x, z, h, base_y, rng.randf_range(0, 360))
		if node != null:
			_tint(node, tint_mul * rng.randf_range(0.85, 1.1))


func _lantern_asset(x: float, base_y: float, z: float, h: float, rot_y: float) -> void:
	var n := _spawn("T16_lantern.glb", x, z, h, base_y, rot_y)
	if n == null:
		return
	# 火袋内的暖光（只补光，不再有发光块）
	var ol := OmniLight3D.new()
	ol.light_color = Color(1.0, 0.72, 0.36)
	ol.light_energy = 1.8
	ol.omni_range = 2.6
	ol.position = Vector3(x, base_y + h * 0.55, z)
	add_child(ol)

# ---------------- 悬浮微粒 ----------------
func _build_dust() -> void:
	var p := GPUParticles3D.new()
	p.amount = 300
	p.lifetime = 20.0
	p.preprocess = 6.0
	p.visibility_aabb = AABB(Vector3(-20, -8, -26), Vector3(40, 18, 34))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(13, 5, 8)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 55.0
	pm.initial_velocity_min = 0.03
	pm.initial_velocity_max = 0.16
	pm.gravity = Vector3(0.01, 0.03, 0)
	pm.scale_min = 0.4
	pm.scale_max = 1.0
	var g := Gradient.new()
	g.set_color(0, Color(0.65, 0.96, 1.0, 1.0))
	g.set_color(1, Color(0.45, 0.85, 0.95, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm

	var quad := QuadMesh.new()
	quad.size = Vector2(0.02, 0.02)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(0.75, 1.0, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.55, 0.95, 1.0)
	mat.emission_energy_multiplier = 1.6
	quad.material = mat
	p.draw_pass_1 = quad
	p.position = Vector3(0, 2.0, -6.0)
	add_child(p)
