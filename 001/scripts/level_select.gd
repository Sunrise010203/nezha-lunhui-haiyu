extends Control
## 选关界面：自由选择章节，两章互相独立
## 每关从自己的第一盏莲台开始；死亡只在本关莲台复活；通关后回到这里。

const GOLD := Color(0.95, 0.78, 0.35)
const GOLD_DIM := Color(0.62, 0.5, 0.25)
const CYAN := Color(0.45, 0.85, 0.85)

const CHAPTERS := [
	{
		"id": "ch1",
		"title": "第一章 · 东海 碎潮回廊",
		"sub": "龙宫外廊 · 潮汐异变 · 归墟之喉",
		"scene": "res://scenes/level_1.tscn",
	},
	{
		"id": "ch2",
		"title": "第二章 · 龙宫深狱",
		"sub": "铁狱深潜 · 狱火喷口 · 棘狱守卫",
		"scene": "res://scenes/level_2.tscn",
	},
	{
		"id": "ch3",
		"title": "第三章 · 归墟虚空「海眼」",
		"sub": "归墟虚空 · 混天绫摆荡 · 归墟海眼",
		"scene": "res://scenes/level_3.tscn",
	},
	{
		"id": "ch4",
		"title": "第四章 · 龙骨沉殿「潮心」",
		"sub": "龙骨沉殿 · 定潮弹反 · 潮心螭吻",
		"scene": "res://scenes/level_4.tscn",
	},
]

var _cards: Array[Button] = []


func _ready() -> void:
	Game.start_ambient()
	Game.play_theme(true)
	_build_background()
	_build_title()
	_build_cards()
	_build_footer()
	Game.scene_ready()
	if _cards.size() > 0:
		_cards[0].grab_focus()


func _build_background() -> void:
	var art := Game.tex("res://art/menu_bg.png")
	if art:
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


func _build_title() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.offset_top = 96
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)

	var sub := Label.new()
	sub.text = "—— 轮 回 之 路 · 任 选 一 章 ——"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 24)
	sub.add_theme_color_override("font_color", CYAN * Color(1, 1, 1, 0.8))
	box.add_child(sub)

	var title := Label.new()
	title.text = "选 择 关 卡"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 76)
	title.add_theme_color_override("font_color", GOLD)
	title.add_theme_color_override("font_shadow_color", Color(0.9, 0.3, 0.05, 0.5))
	title.add_theme_constant_override("shadow_offset_y", 5)
	box.add_child(title)


func _panel_style(border: Color, alpha := 0.72,
		border_w := 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.07, 0.10, alpha)
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(10)
	return sb


func _build_cards() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.offset_top = 64
	box.add_theme_constant_override("separation", 16)
	add_child(box)

	for ch: Dictionary in CHAPTERS:
		var card := _chapter_card(ch)
		var center := CenterContainer.new()
		center.add_child(card)
		box.add_child(center)
		_cards.append(card)

	box.add_child(_spacer(6))
	var back := _make_button("返 回 主 菜 单")
	back.pressed.connect(func() -> void:
		Game.play_sfx("ui", -6.0)
		Game.change_scene("res://scenes/main_menu.tscn"))
	var center2 := CenterContainer.new()
	center2.add_child(back)
	box.add_child(center2)


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _chapter_card(ch: Dictionary) -> Button:
	var cleared := Game.is_cleared(ch["id"])
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(900, 118)
	btn.focus_mode = Control.FOCUS_ALL
	btn.add_theme_stylebox_override("normal",
		_panel_style(GOLD_DIM, 0.72))
	btn.add_theme_stylebox_override("hover",
		_panel_style(GOLD, 0.9, 2))
	btn.add_theme_stylebox_override("pressed",
		_panel_style(GOLD, 0.95, 2))
	btn.add_theme_stylebox_override("focus",
		_panel_style(CYAN, 0.88, 2))
	btn.pressed.connect(func() -> void: _start_chapter(ch))
	btn.mouse_entered.connect(func() -> void: Game.play_sfx("ui", -10.0, 1.3))

	# 卡片内容叠在按钮上（不接收鼠标，点击穿透到按钮）
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 32
	vb.offset_right = -32
	vb.offset_top = 18
	vb.offset_bottom = -18
	vb.add_theme_constant_override("separation", 6)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vb)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(row)

	var title := Label.new()
	title.text = ch["title"]
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", GOLD)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(title)

	var grow := Control.new()
	grow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(grow)

	var status := Label.new()
	if cleared:
		var bt := Game.best_time(ch["id"])
		if bt > 0.0:
			var mins := int(bt) / 60
			var secs := int(bt) % 60
			status.text = "✓ 已通关　·　最快 %02d:%02d" % [mins, secs]
		else:
			status.text = "✓  已 通 关"
	else:
		status.text = "未 通 关"
	status.add_theme_font_size_override("font_size", 22)
	status.add_theme_color_override("font_color",
		Color(0.55, 1.0, 0.75) if cleared else Color(0.62, 0.68, 0.7, 0.8))
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(status)

	var sub := Label.new()
	sub.text = ch["sub"]
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", Color(0.72, 0.82, 0.82, 0.85))
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(sub)

	return btn


func _make_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(420, 58)
	btn.focus_mode = Control.FOCUS_ALL
	btn.add_theme_font_size_override("font_size", 26)
	btn.add_theme_color_override("font_color", Color(0.85, 0.85, 0.82))
	btn.add_theme_color_override("font_hover_color", GOLD)
	btn.add_theme_stylebox_override("normal", _panel_style(GOLD_DIM, 0.72))
	btn.add_theme_stylebox_override("hover", _panel_style(GOLD, 0.9, 2))
	btn.add_theme_stylebox_override("pressed", _panel_style(GOLD, 0.95, 2))
	btn.add_theme_stylebox_override("focus", _panel_style(CYAN, 0.86, 2))
	btn.mouse_entered.connect(func() -> void: Game.play_sfx("ui", -10.0, 1.3))
	return btn


func _build_footer() -> void:
	var lbl := Label.new()
	lbl.text = "选关模式：全技能解锁，三章独立；死亡在本关莲台复活。闯关模式请从主菜单「开始游戏」进入。"
	lbl.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	lbl.anchor_top = 0.945
	lbl.anchor_bottom = 0.945
	lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(0.6, 0.7, 0.7, 0.6))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)


func _start_chapter(ch: Dictionary) -> void:
	Game.play_sfx("checkpoint", -3.0)
	# 选关模式：全部技能解锁（闯关模式靠龙魂残片逐个解锁）
	Game.start_select_mode()
	Game.play_theme(false)
	Game.change_scene(ch["scene"])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		Game.play_sfx("ui", -6.0)
		Game.change_scene("res://scenes/main_menu.tscn")
		get_viewport().set_input_as_handled()
