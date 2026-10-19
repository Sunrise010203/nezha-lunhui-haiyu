extends Node
## 全局单例：输入注册、音效合成、场景过渡、通用特效辅助

signal shake_requested(strength: float)
signal soul_collected(total: int)


var world_font: SystemFont
var run_time := 0.0
var death_count := 0
var run_active := false
var souls := 0
var intro_target := "level"   # 序章结束后去向：level / menu


func collect_soul() -> void:
	souls += 1
	soul_collected.emit(souls)


func tex(path: String) -> Texture2D:
	## 加载生成的美术资源，不存在则返回 null（调用方需有程序化兜底）
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


func load_model(path: String, height: float, yaw_deg := 0.0,
		pitch_deg := -90.0, vis_end := 0.0, cast_shadow := true) -> Node3D:
	## 加载 AI 生成的 GLB 模型：套顶点色材质、旋正（TripoSR 为 Z 轴朝上）、
	## 统一缩放到目标高度、底部对齐 y=0。文件不存在返回 null（调用方逐级兜底）
	if not ResourceLoader.exists(path):
		return null
	var ps := load(path) as PackedScene
	if ps == null:
		return null
	var inst := ps.instantiate() as Node3D
	var meshes := inst.find_children("*", "MeshInstance3D", true, false)
	for mi: MeshInstance3D in meshes:
		_apply_model_material(mi)
		# AI 模型面数很高（crawler 15.9 万 / shooter 26 万三角形），
		# 加 LOD 偏置与可见距离，避免相机外的模型还在画
		mi.lod_bias = 1.4
		mi.extra_cull_margin = 0.6
		if vis_end > 0.0:
			mi.visibility_range_end = vis_end
			mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		if not cast_shadow:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# 归一化结果按 (路径+参数) 缓存：重复实例化同一模型时跳过 AABB 遍历
	var key := "%s|%.2f|%.1f|%.1f" % [path, height, yaw_deg, pitch_deg]
	var fit: Dictionary = _model_fit.get(key, {})
	if fit.is_empty():
		fit = _compute_model_fit(meshes, height, yaw_deg, pitch_deg)
		if fit.is_empty():
			inst.queue_free()
			return null
		_model_fit[key] = fit
	var rot: Basis = fit["rot"]
	var s: float = fit["scale"]
	var off: Vector3 = fit["offset"]
	var wrapper := Node3D.new()
	var pivot := Node3D.new()
	wrapper.add_child(pivot)
	pivot.add_child(inst)
	pivot.transform = Transform3D(rot.scaled(Vector3(s, s, s)), off)
	return wrapper


func _apply_model_material(mi: MeshInstance3D) -> void:
	## 带烘焙贴图的模型保留导入材质；否则套顶点色材质。
	## base_mat meta 供 flash_meshes() 受击白闪后还原。
	var has_tex := false
	if mi.mesh and mi.mesh.get_surface_count() > 0:
		var sm := mi.mesh.surface_get_material(0) as BaseMaterial3D
		if sm and sm.albedo_texture:
			has_tex = true
	if has_tex:
		mi.set_meta("base_mat", null)
	else:
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = 0.8
		mi.material_override = m
		mi.set_meta("base_mat", m)


func _compute_model_fit(meshes: Array, height: float, yaw_deg: float,
		pitch_deg: float) -> Dictionary:
	var aabb := AABB()
	var first := true
	for mi: MeshInstance3D in meshes:
		var box := mi.transform * mi.get_aabb()
		if first:
			aabb = box
			first = false
		else:
			aabb = aabb.merge(box)
	if first or aabb.size.y <= 0.0001:
		return {}
	var rot := Basis.from_euler(Vector3(deg_to_rad(pitch_deg),
		deg_to_rad(yaw_deg), 0))
	var rmin := Vector3.INF
	var rmax := -Vector3.INF
	for i in 8:
		var c := rot * aabb.get_endpoint(i)
		rmin = rmin.min(c)
		rmax = rmax.max(c)
	var s := height / maxf(rmax.y - rmin.y, 0.0001)
	return {
		"rot": rot,
		"scale": s,
		"offset": -Vector3((rmin.x + rmax.x) * 0.5, rmin.y,
			(rmin.z + rmax.z) * 0.5) * s,
	}

var _fade: ColorRect
var _loading_title: Label
var _loading_hint: Label
var _changing := false
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sounds := {}
var _ambient_player: AudioStreamPlayer
var _theme_player: AudioStreamPlayer
## GLB 归一化缓存：path -> {rot: Basis, scale: float, offset: Vector3}
## 避免每次实例化高面数模型都重新遍历网格算 AABB
var _model_fit := {}


func _init() -> void:
	_register_inputs()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	world_font = SystemFont.new()
	world_font.font_names = PackedStringArray(
		["Microsoft YaHei UI", "Microsoft YaHei", "SimHei", "NSimSun"])
	_build_fade_layer()
	_build_audio()


func _process(delta: float) -> void:
	if run_active and not get_tree().paused:
		run_time += delta


# ---------------------------------------------------------------- 输入注册

func _register_inputs() -> void:
	var key_actions := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE, KEY_W, KEY_UP],
		"attack": [KEY_J],
		"heavy": [KEY_K],
		"dash": [KEY_SHIFT, KEY_L],
		"skill": [KEY_Q, KEY_U],
		"skill2": [KEY_E, KEY_I],
		"pause": [KEY_ESCAPE],
	}
	for action: String in key_actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key: Key in key_actions[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	var mouse_actions := {
		"attack": MOUSE_BUTTON_LEFT,
		"heavy": MOUSE_BUTTON_RIGHT,
	}
	for action: String in mouse_actions:
		var ev := InputEventMouseButton.new()
		ev.button_index = mouse_actions[action]
		InputMap.action_add_event(action, ev)


# ---------------------------------------------------------------- 场景过渡

func _build_fade_layer() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 120
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.0, 0.01, 0.02)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 启动时先盖黑，等第一个场景建好再淡出（避免看到半成品画面）
	_fade.modulate.a = 1.0
	layer.add_child(_fade)

	# 黑屏上的章节标题 + 提示：关卡分帧构建期间显示
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(box)

	_loading_title = Label.new()
	_loading_title.text = ""
	_loading_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_title.add_theme_font_size_override("font_size", 46)
	_loading_title.add_theme_color_override("font_color", Color(0.95, 0.78, 0.35))
	_loading_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_loading_title.add_theme_constant_override("shadow_offset_y", 3)
	box.add_child(_loading_title)

	_loading_hint = Label.new()
	_loading_hint.text = ""
	_loading_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_hint.add_theme_font_size_override("font_size", 22)
	_loading_hint.add_theme_color_override("font_color", Color(0.62, 0.72, 0.72, 0.8))
	box.add_child(_loading_hint)


func change_scene(path: String) -> void:
	## 淡出到黑 → 换场景 → 由目标场景调用 scene_ready() 淡入。
	## 这样重场景（关卡）可以在黑屏下分帧构建，不会露出半成品画面。
	if _changing:
		return
	_changing = true
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_fade, "modulate:a", 1.0, 0.35)
	await tw.finished
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file(path)
	_changing = false


func show_loading(title: String, hint := "") -> void:
	## 关卡构建期间在黑屏上显示章节名
	_loading_title.text = title
	_loading_hint.text = hint
	if _fade.modulate.a < 1.0:
		var tw := create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(_fade, "modulate:a", 1.0, 0.2)


func set_loading_hint(hint: String) -> void:
	_loading_hint.text = hint


func scene_ready() -> void:
	## 目标场景准备就绪：黑屏淡出，允许操作
	_loading_title.text = ""
	_loading_hint.text = ""
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_fade, "modulate:a", 0.0, 0.45)


func flash_fade(dur := 0.35) -> void:
	## 快速黑屏一下（用于复活传送）
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_fade, "modulate:a", 1.0, dur * 0.4)
	tw.tween_interval(dur * 0.2)
	tw.tween_property(_fade, "modulate:a", 0.0, dur * 0.4)


# ---------------------------------------------------------------- 打击感

func hitstop(dur := 0.06, ts := 0.05) -> void:
	if Engine.time_scale < 1.0:
		return
	Engine.time_scale = ts
	await get_tree().create_timer(dur, true, false, true).timeout
	Engine.time_scale = 1.0


func shake(strength := 0.3) -> void:
	shake_requested.emit(strength)


# ---------------------------------------------------------------- 材质 / 网格辅助

func std_mat(albedo: Color, emission := Color.BLACK, e_energy := 1.0,
		rough := 0.75, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.roughness = rough
	m.metallic = metal
	if emission != Color.BLACK:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = e_energy
	return m


func add_mesh(parent: Node, mesh: Mesh, mat: Material, pos: Vector3,
		rot_deg := Vector3.ZERO, scl := Vector3.ONE,
		cast_shadow := false) -> MeshInstance3D:
	## 默认不投影：关卡里 400+ 个装饰网格如果全开阴影，阴影 pass 会占掉 80% 的
	## draw call（实测 331→66）。需要投影的（角色/敌人等）显式传 true。
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadow \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("base_mat", mat)
	parent.add_child(mi)
	return mi


func flash_meshes(root: Node, color := Color(1, 1, 1), dur := 0.09) -> void:
	## 受击白闪：网格临时换材质，精灵临时调 modulate
	var flash := StandardMaterial3D.new()
	flash.albedo_color = color
	flash.emission_enabled = true
	flash.emission = color
	flash.emission_energy_multiplier = 2.5
	var meshes := root.find_children("*", "MeshInstance3D", true, false)
	for mi: MeshInstance3D in meshes:
		mi.material_override = flash
	var sprites := root.find_children("*", "Sprite3D", true, false)
	for sp: Sprite3D in sprites:
		if not sp.has_meta("base_mod"):
			sp.set_meta("base_mod", sp.modulate)
		sp.modulate = color * 2.2
	await get_tree().create_timer(dur, false, true).timeout
	if not is_instance_valid(root):
		return
	for mi in meshes:
		if is_instance_valid(mi):
			mi.material_override = mi.get_meta("base_mat", null)
	for sp in sprites:
		if is_instance_valid(sp):
			sp.modulate = sp.get_meta("base_mod", Color.WHITE)


func burst(parent: Node, pos: Vector3, color: Color, count := 24,
		speed := 6.0, size := 0.09, life := 0.6) -> void:
	## 一次性粒子爆发
	var p := GPUParticles3D.new()
	p.one_shot = true
	p.amount = count
	p.lifetime = life
	p.explosiveness = 1.0
	p.position = pos
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3.UP
	mat.spread = 180.0
	mat.initial_velocity_min = speed * 0.4
	mat.initial_velocity_max = speed
	mat.gravity = Vector3(0, -4.0, 0)
	mat.damping_min = 2.0
	mat.damping_max = 4.0
	mat.scale_min = 0.5
	mat.scale_max = 1.4
	var grad := Gradient.new()
	grad.set_color(0, color)
	grad.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	mat.color_ramp = gt
	p.process_material = mat
	var sphere := SphereMesh.new()
	sphere.radius = size
	sphere.height = size * 2.0
	sphere.radial_segments = 6
	sphere.rings = 3
	var sm := StandardMaterial3D.new()
	sm.albedo_color = color
	sm.emission_enabled = true
	sm.emission = color
	sm.emission_energy_multiplier = 2.0
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.vertex_color_use_as_albedo = true
	sphere.material = sm
	p.draw_pass_1 = sphere
	parent.add_child(p)
	p.emitting = true
	get_tree().create_timer(life + 0.5, false).timeout.connect(p.queue_free)


func spawn_dmg_text(parent: Node, pos: Vector3, text: String, color: Color,
		big := false) -> void:
	var lbl := Label3D.new()
	lbl.text = text
	lbl.font = world_font
	lbl.font_size = 96 if big else 64
	lbl.outline_size = 18
	lbl.outline_modulate = Color(0, 0, 0, 0.85)
	lbl.modulate = color
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.pixel_size = 0.008
	lbl.position = pos + Vector3(randf_range(-0.3, 0.3), 0.4, 0.5)
	parent.add_child(lbl)
	var tw := lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y + 1.3, 0.7) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.7).set_delay(0.25)
	tw.chain().tween_callback(lbl.queue_free)


# ---------------------------------------------------------------- 音效合成

func play_sfx(sname: String, vol_db := 0.0, pitch := 1.0) -> void:
	if not _sounds.has(sname):
		return
	for p in _sfx_pool:
		if not p.playing:
			p.stream = _sounds[sname]
			p.volume_db = vol_db
			p.pitch_scale = pitch * randf_range(0.94, 1.06)
			p.play()
			return


func start_ambient() -> void:
	if not _ambient_player.playing:
		_ambient_player.play()


func play_theme(active: bool) -> void:
	if active and not _theme_player.playing:
		_theme_player.play()
	elif not active and _theme_player.playing:
		_theme_player.stop()


func _build_audio() -> void:
	for i in 14:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_pool.append(p)

	# 优先加载离线烘焙结果（tools/bake_audio.gd 生成），缺失时实时合成兜底
	for n: String in AudioSynth.SOUND_NAMES:
		var s := _load_stream("res://audio/sfx_%s.res" % n,
			AudioSynth.sound.bind(n))
		if s:
			_sounds[n] = s
	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.stream = _load_stream("res://audio/ambient.res",
		AudioSynth.make_ambient)
	_ambient_player.volume_db = -14.0
	add_child(_ambient_player)
	_theme_player = AudioStreamPlayer.new()
	_theme_player.stream = _load_stream("res://audio/theme.res",
		AudioSynth.make_theme)
	_theme_player.volume_db = -10.0
	add_child(_theme_player)


func _load_stream(path: String, fallback: Callable) -> AudioStream:
	if ResourceLoader.exists(path):
		var r: Resource = load(path)
		if r is AudioStream:
			return r as AudioStream
	return fallback.call() as AudioStream

# ---------------------------------------------------------------- 加载预热

func prewarm_fx(parent: Node) -> void:
	## 在屏幕外把一次性特效各跑一遍：D3D12 首次遇到新 shader 管线会有 ~94ms
	## 编译卡顿（实测出现在 Boss 第一次弹幕/砸地时）。放在黑屏加载期间预热，
	## 战斗中就不会再卡。
	var spot := Vector3(0, -300, 0)
	burst(parent, spot, Color(1.0, 0.55, 0.15), 8, 2.0, 0.06, 0.2)
	burst(parent, spot, Color(0.45, 0.9, 0.95), 8, 2.0, 0.06, 0.2)

	var proj := Projectile.new()
	proj.position = spot
	proj.vel = Vector3(0.01, 0.0, 0.0)
	proj.life = 0.15
	parent.add_child(proj)

	# 未受光 + 自发光 + 透明的斩击环（攻击/真火共用同一套材质路径）
	var torus := TorusMesh.new()
	torus.inner_radius = 0.45
	torus.outer_radius = 0.55
	var mat := std_mat(Color(1.0, 0.7, 0.25, 0.85), Color(1.0, 0.55, 0.15),
		3.0, 0.3)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mi := add_mesh(parent, torus, mat, spot)
	mi.rotation_degrees = Vector3(90, 0, 0)
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(1.4, 1.4, 1.4), 0.18)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.18)
	tw.chain().tween_callback(mi.queue_free)

	# 伤害数字：预热 SystemFont 的 64/96 px 字形图集
	spawn_dmg_text(parent, spot, "0", Color.WHITE)
	spawn_dmg_text(parent, spot, "0", Color.WHITE, true)

	var flame := _prewarm_flame()
	flame.position = spot
	parent.add_child(flame)


func _prewarm_flame() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 4
	p.lifetime = 0.2
	var m := ParticleProcessMaterial.new()
	m.gravity = Vector3(0, 2, 0)
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.6, 0.1, 1.0))
	grad.set_color(1, Color(1.0, 0.2, 0.0, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	m.color_ramp = gt
	p.process_material = m
	var sph := SphereMesh.new()
	sph.radius = 0.05
	sph.height = 0.1
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.vertex_color_use_as_albedo = true
	sph.material = sm
	p.draw_pass_1 = sph
	get_tree().create_timer(0.6, false).timeout.connect(p.queue_free)
	return p