extends Control
## 开场序章：逐页剧情插画，点击翻页，可随时跳过
## Game.intro_target 决定结束后去向（关卡或主菜单）

const GOLD := Color(0.95, 0.78, 0.35)

const PAGES := [
	{
		"img": "res://art/story_1.png",
		"title": "三界 · 秩序",
		"text": "天地初开，天界、人间、海域三界由「秩序之力」维系。\n东海龙族世代镇守海域，调节水脉与灵气——潮汐有序，万灵安生。",
	},
	{
		"img": "res://art/story_2.png",
		"title": "归墟 · 苏醒",
		"text": "然而，被诸神遗忘的「归墟之力」自深海底层悄然苏醒。\n它吞噬秩序，将世界拉向混沌：潮汐紊乱、生灵异化、空间破碎。\n龙宫封印接连崩裂，异化的海族在碎裂的回廊间游荡。",
	},
	{
		"img": "res://art/story_3.png",
		"title": "哪吒 · 入海",
		"text": "莲花化身、踏轮回而来的哪吒，手持火尖枪、足踏风火轮，\n自天界坠入这片倒卷的海域。\n从碎潮回廊到龙宫深狱，再潜入归墟虚空的海眼——\n集满每章的 3 枚龙魂残片，可唤醒新的神通。",
	},
]

var _page := -1
var _img: TextureRect
var _title: Label
var _text: Label
var _hint: Label
var _busy := false


func _ready() -> void:
	Game.start_ambient()
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.01, 0.02)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_img = TextureRect.new()
	_img.set_anchors_preset(Control.PRESET_FULL_RECT)
	_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_img)

	# 底部渐暗，保证文字可读
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vmat := ShaderMaterial.new()
	vmat.shader = load("res://shaders/vignette.gdshader")
	dim.material = vmat
	add_child(dim)
	var grad := ColorRect.new()
	grad.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	grad.anchor_top = 0.68
	grad.color = Color(0, 0.01, 0.02, 0.55)
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(grad)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	box.anchor_top = 0.72
	box.offset_left = 200
	box.offset_right = -200
	box.add_theme_constant_override("separation", 14)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 44)
	_title.add_theme_color_override("font_color", GOLD)
	_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_title.add_theme_constant_override("shadow_offset_y", 3)
	box.add_child(_title)

	_text = Label.new()
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.add_theme_font_size_override("font_size", 24)
	_text.add_theme_color_override("font_color", Color(0.9, 0.92, 0.92))
	_text.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_text.add_theme_constant_override("shadow_offset_y", 2)
	box.add_child(_text)

	_hint = Label.new()
	_hint.text = "点击 / 空格　继续"
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.anchor_top = 0.955
	_hint.anchor_bottom = 0.955
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 18)
	_hint.add_theme_color_override("font_color", Color(0.7, 0.75, 0.75, 0.6))
	add_child(_hint)
	var htw := _hint.create_tween()
	htw.set_loops()
	htw.tween_property(_hint, "modulate:a", 0.35, 1.0)
	htw.tween_property(_hint, "modulate:a", 1.0, 1.0)

	# 跳过按钮
	var skip := Button.new()
	skip.text = "跳 过 ≫"
	skip.flat = true
	skip.focus_mode = Control.FOCUS_NONE
	skip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip.position = Vector2(-160, 30)
	skip.add_theme_font_size_override("font_size", 24)
	skip.add_theme_color_override("font_color", Color(0.8, 0.82, 0.82, 0.7))
	skip.add_theme_color_override("font_hover_color", GOLD)
	skip.pressed.connect(_finish)
	add_child(skip)

	_next_page()
	Game.scene_ready()


func _input(event: InputEvent) -> void:
	var advance := false
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		advance = true
	elif event.is_action_pressed("jump") or event.is_action_pressed("attack"):
		advance = true
	if advance and not _busy:
		_next_page()


func _next_page() -> void:
	_page += 1
	if _page >= PAGES.size():
		_finish()
		return
	Game.play_sfx("ui", -8.0)
	_busy = true
	var page: Dictionary = PAGES[_page]
	var fade := create_tween()
	if _page > 0:
		fade.tween_property(self, "modulate:a", 0.0, 0.25)
	fade.tween_callback(func() -> void:
		_img.texture = Game.tex(page["img"])
		_title.text = page["title"]
		_text.text = page["text"])
	fade.tween_property(self, "modulate:a", 1.0, 0.45)
	fade.tween_callback(func() -> void: _busy = false)


func _finish() -> void:
	Game.play_theme(false)
	match Game.intro_target:
		"campaign":
			# 闯关模式：从第一章开始连续闯关（技能靠龙魂解锁）
			Game.start_campaign()
			Game.change_scene("res://scenes/level_1.tscn")
		"select":
			Game.start_select_mode()
			Game.change_scene("res://scenes/level_select.tscn")
		"level":
			Game.start_campaign()
			Game.change_scene("res://scenes/level_1.tscn")
		_:
			Game.change_scene("res://scenes/main_menu.tscn")
	set_process_input(false)
