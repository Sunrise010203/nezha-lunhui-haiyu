extends Control
## 主菜单：深海背景 + 标题 + 按钮 + 世界观/操作说明面板

const GOLD := Color(0.95, 0.78, 0.35)
const GOLD_DIM := Color(0.62, 0.5, 0.25)
const CYAN := Color(0.45, 0.85, 0.85)

var _panel_layer: Control = null
var _title: Label
var _buttons: Array[Button] = []


func _ready() -> void:
	Game.start_ambient()
	Game.play_theme(true)
	_build_background()
	_build_title()
	_build_buttons()
	_build_footer()
	_animate_in()
	Game.scene_ready()


# ---------------------------------------------------------------- 构建

func _build_background() -> void:
	var art := Game.tex("res://art/menu_bg.png")
	if art:
		# AI 主视觉画 + 暗角 + 加法特效叠加层
		var img := TextureRect.new()
		img.texture = art
		img.set_anchors_preset(Control.PRESET_FULL_RECT)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(img)
		var dim := ColorRect.new()
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var vmat := ShaderMaterial.new()
		vmat.shader = load("res://shaders/vignette.gdshader")
		dim.material = vmat
		add_child(dim)
		var fx := ColorRect.new()
		fx.set_anchors_preset(Control.PRESET_FULL_RECT)
		fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fmat := ShaderMaterial.new()
		fmat.shader = load("res://shaders/menu_fx.gdshader")
		fx.material = fmat
		add_child(fx)
	else:
		# 兜底：程序化着色器背景
		var bg := ColorRect.new()
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/menu_bg.gdshader")
		bg.material = mat
		add_child(bg)

	# 上升的气泡粒子
	var bubbles := CPUParticles2D.new()
	bubbles.amount = 40
	bubbles.lifetime = 9.0
	bubbles.preprocess = 9.0
	bubbles.position = Vector2(960, 1140)
	bubbles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	bubbles.emission_rect_extents = Vector2(1000, 20)
	bubbles.direction = Vector2(0, -1)
	bubbles.spread = 12.0
	bubbles.gravity = Vector2.ZERO
	bubbles.initial_velocity_min = 50.0
	bubbles.initial_velocity_max = 140.0
	bubbles.scale_amount_min = 1.5
	bubbles.scale_amount_max = 5.0
	bubbles.color = Color(0.5, 0.85, 0.85, 0.16)
	add_child(bubbles)


func _build_title() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	box.position = Vector2(0, 210)
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(box)

	var sub := Label.new()
	sub.text = "—— 归 墟 苏 醒 · 秩 序 将 倾 ——"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 26)
	sub.add_theme_color_override("font_color", CYAN * Color(1, 1, 1, 0.75))
	box.add_child(sub)

	_title = Label.new()
	_title.text = "哪 吒 · 轮 回 海 域"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 110)
	_title.add_theme_color_override("font_color", GOLD)
	_title.add_theme_color_override("font_shadow_color", Color(0.9, 0.3, 0.05, 0.55))
	_title.add_theme_constant_override("shadow_offset_x", 0)
	_title.add_theme_constant_override("shadow_offset_y", 6)
	_title.add_theme_constant_override("shadow_outline_size", 14)
	box.add_child(_title)

	var chapter := Label.new()
	chapter.text = "第 一 章 ｜ 东 海 · 碎 潮 回 廊"
	chapter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chapter.add_theme_font_size_override("font_size", 30)
	chapter.add_theme_color_override("font_color", Color(0.85, 0.88, 0.88, 0.8))
	box.add_child(chapter)

	# 标题缓慢漂浮
	var tw := _title.create_tween()
	tw.set_loops()
	tw.tween_property(_title, "position:y", 8.0, 2.6) \
		.as_relative().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_title, "position:y", -8.0, 2.6) \
		.as_relative().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _build_buttons() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.anchor_top = 0.62
	box.anchor_bottom = 0.62
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 18)
	add_child(box)

	var entries := [
		["入 海 · 开始游戏", _on_start],
		["世 界 观", _on_lore],
		["操 作 指 南", _on_controls],
		["离 去 · 退出", _on_quit],
	]
	for e: Array in entries:
		var btn := _make_button(e[0])
		btn.pressed.connect(e[1])
		box.add_child(btn)
		_buttons.append(btn)


func _make_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(420, 64)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 28)
	btn.add_theme_color_override("font_color", Color(0.85, 0.85, 0.82))
	btn.add_theme_color_override("font_hover_color", GOLD)
	btn.add_theme_color_override("font_pressed_color", GOLD)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.07, 0.10, 0.72)
	sb.border_color = GOLD_DIM
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	btn.add_theme_stylebox_override("normal", sb)

	var sbh := sb.duplicate() as StyleBoxFlat
	sbh.bg_color = Color(0.05, 0.13, 0.16, 0.9)
	sbh.border_color = GOLD
	sbh.set_border_width_all(2)
	btn.add_theme_stylebox_override("hover", sbh)

	var sbp := sbh.duplicate() as StyleBoxFlat
	sbp.bg_color = Color(0.10, 0.18, 0.20, 0.95)
	btn.add_theme_stylebox_override("pressed", sbp)

	btn.mouse_entered.connect(func() -> void:
		Game.play_sfx("ui", -8.0, 1.3)
		var tw := btn.create_tween()
		tw.tween_property(btn, "scale", Vector2(1.04, 1.04), 0.1)
		btn.pivot_offset = btn.size / 2.0)
	btn.mouse_exited.connect(func() -> void:
		var tw := btn.create_tween()
		tw.tween_property(btn, "scale", Vector2.ONE, 0.1))
	return btn


func _build_footer() -> void:
	var lbl := Label.new()
	lbl.text = "天地初开，三界由秩序之力维系。如今深渊已醒，潮汐倒卷……唯莲花化身者，可逆流而上。"
	lbl.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	lbl.anchor_top = 0.94
	lbl.anchor_bottom = 0.94
	lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.65, 0.66, 0.55))
	add_child(lbl)


func _animate_in() -> void:
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.8)


# ---------------------------------------------------------------- 面板

func _show_panel(title_text: String, body_text: String) -> void:
	_close_panel()
	Game.play_sfx("ui", -4.0)

	_panel_layer = Control.new()
	_panel_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_panel_layer)

	var dim := ColorRect.new()
	dim.color = Color(0, 0.01, 0.02, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_layer.add_child(dim)
	dim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			_close_panel())

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(860, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.015, 0.05, 0.075, 0.96)
	sb.border_color = GOLD_DIM
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(36)
	panel.add_theme_stylebox_override("panel", sb)
	_panel_layer.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", GOLD)
	vbox.add_child(title)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.text = body_text
	body.fit_content = true
	body.custom_minimum_size = Vector2(780, 0)
	body.add_theme_font_size_override("normal_font_size", 22)
	body.add_theme_font_size_override("bold_font_size", 23)
	body.add_theme_color_override("default_color", Color(0.82, 0.86, 0.86))
	vbox.add_child(body)

	var close := _make_button("返 回")
	close.custom_minimum_size = Vector2(200, 52)
	close.pressed.connect(_close_panel)
	var center := CenterContainer.new()
	center.add_child(close)
	vbox.add_child(center)

	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2(0.92, 0.92)
	panel.modulate.a = 0.0
	var tw := panel.create_tween()
	tw.set_parallel(true)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, 0.15)


func _close_panel() -> void:
	if _panel_layer:
		_panel_layer.queue_free()
		_panel_layer = null


# ---------------------------------------------------------------- 按钮回调

func _on_start() -> void:
	Game.play_sfx("checkpoint", -2.0)
	Game.run_time = 0.0
	Game.death_count = 0
	set_process_input(false)
	for b in _buttons:
		b.disabled = true
	if Game.tex("res://art/story_1.png"):
		Game.intro_target = "level"
		Game.change_scene("res://scenes/intro.tscn")
	else:
		Game.play_theme(false)
		Game.change_scene("res://scenes/level_1.tscn")


func _on_lore() -> void:
	if Game.tex("res://art/story_1.png"):
		Game.intro_target = "menu"
		Game.change_scene("res://scenes/intro.tscn")
		return
	_show_panel("世 界 观",
		"[b]天地初开，三界——天界、人间、海域——由「秩序之力」维系。[/b]\n\n" +
		"东海龙族世代镇守海域，调节水脉与灵气，使潮汐有序、万灵安生。\n\n" +
		"然而，被诸神遗忘的[color=#c06ae0]「归墟之力」[/color]自深海底层悄然苏醒。" +
		"它吞噬秩序，将世界拉向混沌：潮汐紊乱、生灵异化、空间破碎。" +
		"龙宫封印接连崩裂，异化的海族在碎裂的回廊间游荡。\n\n" +
		"莲花化身、踏轮回而来的[color=#f2c75c]哪吒[/color]，手持火尖枪、" +
		"足踏风火轮，自天界坠入这片倒卷的海域。\n\n" +
		"[b]第一章 · 东海碎潮回廊[/b]：穿过崩塌的龙宫外廊，斩除异化之物，" +
		"在归墟的喉口——镇压那只自深渊探出的「渊狱兽」。")


func _on_controls() -> void:
	_show_panel("操 作 指 南",
		"[b]移动[/b]　A / D 或 ← / →\n" +
		"[b]跳跃[/b]　空格（可二段跳）\n" +
		"[b]冲刺[/b]　Shift 或 L —— 冲刺瞬间无敌，可穿过攻击\n\n" +
		"[b]火尖枪 · 连击[/b]　J 或 鼠标左键（三连击，第三击更重）\n" +
		"[b]重 击[/b]　K 或 鼠标右键（蓄力横扫，击退敌人）\n" +
		"[b]坠地重砸[/b]　空中按 K（俯冲砸地，范围伤害）\n" +
		"[b]乾坤圈[/b]　E 或 I（消耗 25 灵力，掷出回旋金环，去回各伤一次）\n" +
		"[b]三昧真火[/b]　Q 或 U（消耗 50 灵力，烈焰新星 + 灼烧）\n\n" +
		"[color=#7fd8d8]灵力获取：普攻命中 +10，重击 +18，乾坤圈每段 +6，击杀 +15，灵珠 +12。[/color]\n" +
		"[color=#7fd8d8]完美闪身：冲刺穿过攻击的瞬间触发时缓，并回复 15 灵力。[/color]\n" +
		"[color=#f2c75c]探索：击碎渊晶瓮可得灵珠；寻找散落的 3 枚龙魂残片。[/color]\n" +
		"[color=#7fd8d8]莲台祭坛可恢复气血并记录重生点。[/color]\n" +
		"[color=#e08080]坠入深渊会受伤并被送回莲台，小心碎裂的浮桥。[/color]\n\n" +
		"[b]暂停[/b]　Esc")


func _on_quit() -> void:
	get_tree().quit()
