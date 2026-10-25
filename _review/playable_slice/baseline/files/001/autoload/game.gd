extends Node
## 全局单例：输入注册、音效合成、场景过渡、通用特效辅助

signal shake_requested(strength: float)
signal soul_collected(total: int)
signal skill_unlocked(id: String, title: String)

## §4.6 语义色规范：危险/奖励/路径/治疗，所有特效与材质都从这里取色，避免"粉=治疗又=危险"。
const SEM_DANGER := Color("ff4a32")   # 预警圈/带、刺、受击
const SEM_REWARD := Color("f2c14e")   # 龙魂、门、检查点
const SEM_PATH := Color("4fe8ff")     # 摆荡环、抓点
const SEM_HEAL := Color("5fe08c")     # 回春莲、治疗

## 闯关模式（连续三章，技能靠龙魂解锁） / 选关模式（全技能，单章独立）
var campaign := false
var campaign_chapter := "ch1"
const CAMPAIGN_ORDER := ["ch1", "ch2", "ch3", "ch4"]
## 技能解锁顺序：Q 初始就有；每集满一章的龙魂残片解锁下一个，最多两个
const SKILL_UNLOCK_ORDER := [["E", "乾坤圈"], ["V", "风火轮"]]
var skills := {"Q": true, "E": false, "V": false}
## 第四章「定潮」：只有本章存在（LevelBase 在 _ready 里按 chapter_id 打开）。
## 这样前三章没有弹反与潮纹，已通关章节的手感一点不变。
var tide_unlocked := false
var chapter_souls := 0         # 闯关模式：本章已收集的龙魂残片数
var unlocked_chapters := {}    # 本局已在哪些章发过技能奖励（防止重打同一章刷技能）

var world_font: SystemFont
var _outline_mat: ShaderMaterial
var run_time := 0.0
var death_count := 0
var run_active := false
var souls := 0
var intro_target := "select"   # 序章结束后去向：select / level / menu
var cleared := {}              # 已通关章节 {"ch1": true, "ch2": true}
var best_times := {}           # 每章最快通关时间（秒）{"ch1": 123.4}
const PROGRESS_PATH := "user://progress.cfg"


func start_run() -> void:
	## 开始一局：清空计时/死亡数/龙魂。闯关模式不清技能与当前章节
	run_time = 0.0
	death_count = 0
	souls = 0
	chapter_souls = 0
	run_active = true


func start_campaign() -> void:
	## 闯关模式：从第一章开始，只有 Q 技能，靠集满龙魂解锁
	campaign = true
	campaign_chapter = "ch1"
	skills = {"Q": true, "E": false, "V": false}
	unlocked_chapters = {}
	start_run()


func start_select_mode() -> void:
	## 选关模式：全部技能解锁，单章独立
	campaign = false
	skills = {"Q": true, "E": true, "V": true}
	start_run()


func has_skill(id: String) -> bool:
	return bool(skills.get(id, false))


func skill_key(id: String) -> String:
	match id:
		"Q":
			return "Q"
		"E":
			return "E"
		"V":
			return "V"
	return "?"


func _unlock_next_skill() -> void:
	for pair: Array in SKILL_UNLOCK_ORDER:
		if not has_skill(pair[0]):
			skills[pair[0]] = true
			skill_unlocked.emit(pair[0], pair[1])
			return


func campaign_next_chapter() -> String:
	var idx := CAMPAIGN_ORDER.find(campaign_chapter)
	if idx >= 0 and idx + 1 < CAMPAIGN_ORDER.size():
		return CAMPAIGN_ORDER[idx + 1]
	return ""


func campaign_scene(chapter: String) -> String:
	match chapter:
		"ch1":
			return "res://scenes/level_1.tscn"
		"ch2":
			return "res://scenes/level_2.tscn"
		"ch3":
			return "res://scenes/level_3.tscn"
		"ch4":
			return "res://scenes/level_4.tscn"
	return ""


func enter_campaign_chapter(chapter: String) -> void:
	if chapter == "":
		return
	campaign = true
	campaign_chapter = chapter
	# 新章节从 0 枚龙魂重新收集（HUD 显示 x/3，不会累计到 4/3）
	chapter_souls = 0
	souls = 0


func mark_cleared(chapter: String) -> void:
	if chapter == "":
		return
	cleared[chapter] = true
	# 记录本章最快通关时间（同一章只保留最快的一次）
	if run_time > 0.0:
		var old := float(best_times.get(chapter, 0.0))
		if old <= 0.0 or run_time < old:
			best_times[chapter] = run_time
	_save_progress()


func is_cleared(chapter: String) -> bool:
	return bool(cleared.get(chapter, false))


func best_time(chapter: String) -> float:
	## 本章最快通关时间（秒）；没有记录返回 0
	return float(best_times.get(chapter, 0.0))


func _load_progress() -> void:
	var cf := ConfigFile.new()
	if cf.load(PROGRESS_PATH) == OK:
		var data = cf.get_value("progress", "cleared", {})
		if data is Dictionary:
			cleared = data
		var bt = cf.get_value("progress", "best_times", {})
		if bt is Dictionary:
			best_times = bt


func _save_progress() -> void:
	var cf := ConfigFile.new()
	cf.set_value("progress", "cleared", cleared)
	cf.set_value("progress", "best_times", best_times)
	cf.save(PROGRESS_PATH)


func collect_soul() -> void:
	souls += 1
	if campaign:
		chapter_souls += 1
		# 一章的龙魂残片集满 → 解锁下一个技能（每章只发一次，最多两个）
		if chapter_souls == 3 and not unlocked_chapters.has(campaign_chapter):
			unlocked_chapters[campaign_chapter] = true
			_unlock_next_skill()
	soul_collected.emit(souls)


func tex(path: String) -> Texture2D:
	## 加载生成的美术资源，不存在则返回 null（调用方需有程序化兜底）
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


func load_model(path: String, height: float, yaw_deg := 0.0,
		pitch_deg := -90.0, vis_end := 0.0, cast_shadow := true,
		stylize := true) -> Node3D:
	## 加载 AI 生成的 GLB 模型：套顶点色材质、旋正（TripoSR 为 Z 轴朝上）、
	## 统一缩放到目标高度、底部对齐 y=0。文件不存在返回 null（调用方逐级兜底）
	if not ResourceLoader.exists(path):
		return null
	var ps := load(path) as PackedScene
	if ps == null:
		return null
	var inst := ps.instantiate() as Node3D
	var meshes := inst.find_children("*", "MeshInstance3D", true, false)
	var has_skeleton := not inst.find_children("*", "Skeleton3D", true, false).is_empty()
	for mi: MeshInstance3D in meshes:
		_apply_model_material(mi, not has_skeleton, stylize)
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


func _apply_model_material(mi: MeshInstance3D, outline := true,
		stylize := true) -> void:
	## P1：玩家/敌人统一 toon 阶跃 + rim；非骨骼模型再加反向外扩描边。
	## 逐 surface 复制导入材质，保留原有贴图/顶点色/多材质分面。
	## Boss/大型生物/道具传 stylize=false，保留原材质（toon 会压掉有机细节）。
	if mi.mesh == null or mi.mesh.get_surface_count() == 0:
		return
	if not stylize:
		mi.set_meta("base_mat", "none")
		return
	for i in mi.mesh.get_surface_count():
		var src := mi.mesh.surface_get_material(i) as StandardMaterial3D
		var m: StandardMaterial3D
		if src:
			m = src.duplicate() as StandardMaterial3D
		else:
			m = StandardMaterial3D.new()
			m.vertex_color_use_as_albedo = true
			m.roughness = 0.8
		_stylize_character_mat(m)
		if outline:
			m.next_pass = _get_outline_mat()
		mi.set_surface_override_material(i, m)
	mi.set_meta("base_mat", "none")


func _stylize_character_mat(m: StandardMaterial3D) -> void:
	# 金属件（QiankunGold 乾坤圈/风火轮之类）保留金属度：
	# toon + metallic≤0.15 会把金饰压成塑料，金色是这套角色辨识度最高的一点。
	var nm := m.resource_name.to_lower()
	var metal := nm.contains("gold") or nm.contains("metal") or nm.contains("brass")
	if metal:
		m.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
		m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
		m.roughness = minf(m.roughness, 0.35)
		m.metallic = maxf(m.metallic, 0.55)
		m.rim_enabled = true
		m.rim = 0.22
		m.rim_tint = 0.5
		return
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	m.roughness = maxf(m.roughness, 0.55)
	m.metallic = minf(m.metallic, 0.15)
	m.rim_enabled = true
	m.rim = 0.35
	m.rim_tint = 0.6


func _get_outline_mat() -> ShaderMaterial:
	if _outline_mat == null:
		_outline_mat = ShaderMaterial.new()
		_outline_mat.shader = load("res://shaders/outline.gdshader")
	return _outline_mat


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
	_load_progress()


func _process(delta: float) -> void:
	if run_active and not get_tree().paused:
		run_time += delta


func _unhandled_input(event: InputEvent) -> void:
	## F11：全屏 / 窗口切换（之前的版本强制最大化启动，没有任何显示选项）
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).physical_keycode == KEY_F11:
			var mode := DisplayServer.window_get_mode()
			if mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			get_viewport().set_input_as_handled()


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
		"skill3": [KEY_V, KEY_C],
		"grapple": [KEY_F, KEY_R],
		"tide": [KEY_G, KEY_T],
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


func parry_moment(dur := 0.11, ts := 0.35) -> void:
	## 完美弹反的"世界慢下来"：不是定格，是 0.11 秒的时间稀释。
	## ignore_time_scale 的计时器，避免慢放把恢复时长一起拉长。
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


# ---------------------------------------------------------------- §4.6 统一危险预警环
## 所有 Boss / 场地危险的预警都长成同一套：红外环 + 白心 + 8 段黑刻痕。
## 调用方仍然自己 tween 返回材质的 emission_energy_multiplier 做呼吸。
func warning_ring_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(SEM_DANGER.r, SEM_DANGER.g, SEM_DANGER.b, 0.55)
	m.emission_enabled = true
	m.emission = SEM_DANGER
	m.emission_energy_multiplier = 1.2
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func style_warning_ring(mi: MeshInstance3D, radius: float) -> StandardMaterial3D:
	var mat := warning_ring_material()
	mi.material_override = mat
	# 白心：中心一块高亮，避免整圈糊成红色
	var core := CylinderMesh.new()
	var cr := maxf(radius * 0.16, 0.18)
	core.top_radius = cr
	core.bottom_radius = cr
	core.height = 0.02
	core.radial_segments = 24
	var cm := StandardMaterial3D.new()
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cm.albedo_color = Color(1.0, 0.96, 0.88, 0.9)
	cm.emission_enabled = true
	cm.emission = Color(1.0, 0.90, 0.75)
	cm.emission_energy_multiplier = 2.0
	cm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var core_mi := MeshInstance3D.new()
	core_mi.mesh = core
	core_mi.material_override = cm
	core_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	core_mi.position = Vector3(0, 0.012, 0)
	mi.add_child(core_mi)
	# 8 段黑刻痕：给红环加"刻度"，也让它在亮地板上不会糊成一团光
	var notch := BoxMesh.new()
	notch.size = Vector3(0.09, 0.012, 0.30)
	var nm := StandardMaterial3D.new()
	nm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	nm.albedo_color = Color(0.015, 0.010, 0.008)
	for i in 8:
		var a := TAU * i / 8.0
		var n := MeshInstance3D.new()
		n.mesh = notch
		n.material_override = nm
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.position = Vector3(cos(a) * radius * 0.955, 0.012,
			sin(a) * radius * 0.955)
		n.rotation.y = -a
		mi.add_child(n)
	return mat


# ---------------------------------------------------------------- 灯光 / 接地影（P0 美学速效包）

func tune_light(light: Light3D, energy := -1.0, light_range := -1.0,
		vfe := 0.0, attenuation := 1.6, fade_begin := 12.0) -> Light3D:
	## 统一"小灯"规范：不注入体积雾、收紧范围与衰减、远处淡出。
	## 之前的"整屏紫色/洋红洗地"根因：每只怪自带 OmniLight，VFE 默认 1.0，
	## 几十盏小灯逐 froxel 往雾里注入颜色，把场景照成一片同色。
	if light == null:
		return null
	light.set_meta("light_tuned", true)
	if energy >= 0.0:
		light.light_energy = energy
	light.light_volumetric_fog_energy = vfe
	if light is OmniLight3D:
		var om := light as OmniLight3D
		if light_range > 0.0:
			om.omni_range = light_range
		om.omni_attenuation = attenuation
	light.distance_fade_enabled = true
	light.distance_fade_begin = fade_begin
	light.distance_fade_length = 6.0
	return light


func tune_small_light(light: Light3D, energy := 0.35,
		light_range := 3.4) -> Light3D:
	## 敌人/拾取物/投射物的小灯：默认参数
	return tune_light(light, energy, light_range, 0.0)


func attach_blob_shadow(actor: Node3D, radius := 0.7,
		strength := 0.55) -> void:
	## 给角色挂贴地接触阴影（乘算，不触发 glow）
	if actor == null or not actor.is_inside_tree():
		return
	var s := GroundBlobShadow.new()
	s.actor = actor
	s.base_radius = radius
	s.base_strength = strength
	actor.add_child(s)


func flash_meshes(root: Node, color := Color(1, 1, 1), dur := 0.09) -> void:
	## 受击白闪：网格临时换材质，精灵临时调 modulate
	var flash := StandardMaterial3D.new()
	flash.albedo_color = color
	flash.emission_enabled = true
	flash.emission = color
	flash.emission_energy_multiplier = 2.5
	var meshes := root.find_children("*", "MeshInstance3D", true, false)
	# 先快照原 override：角色的 PBR ShaderMaterial 就挂在这里，白闪结束后必须还原它，
	# 否则玩家挨第一下打就永久掉回 toon 材质。
	var prev: Array = []
	for mi: MeshInstance3D in meshes:
		prev.append(mi.material_override)
		mi.material_override = flash
	var sprites := root.find_children("*", "Sprite3D", true, false)
	for sp: Sprite3D in sprites:
		if not sp.has_meta("base_mod"):
			sp.set_meta("base_mod", sp.modulate)
		sp.modulate = color * 2.2
	await get_tree().create_timer(dur, false, true).timeout
	if not is_instance_valid(root):
		return
	for i in meshes.size():
		var mi = meshes[i]
		if not is_instance_valid(mi):
			continue
		if prev[i] != null:
			mi.material_override = prev[i]
		elif mi.has_meta("base_mat"):
			var base = mi.get_meta("base_mat")
			mi.material_override = base if base is Material else null
		else:
			mi.material_override = null   # 带贴图模型原本就没有 override
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

func _exit_tree() -> void:
	CombatVFX.release_cache()


func prewarm_fx(parent: Node) -> void:
	CombatVFX.warm(parent)
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

# ---------------------------------------------------------------- 轮廓光（可读性）

var _rim_shader: Shader


func make_rim(color: Color, power := 2.8, strength := 0.6) -> ShaderMaterial:
	## 敌人/Boss 的轮廓光叠加材质。深色模型在深色背景里几乎看不见（评审 D-02），
	## 用 material_overlay 加一圈菲涅尔边缘光，不改本体材质、不影响受击白闪。
	if _rim_shader == null:
		_rim_shader = load("res://shaders/rim_overlay.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _rim_shader
	m.set_shader_parameter("rim_color", color)
	m.set_shader_parameter("rim_power", power)
	m.set_shader_parameter("rim_strength", strength)
	return m
