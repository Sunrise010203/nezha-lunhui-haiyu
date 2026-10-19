class_name HUD
extends CanvasLayer
## 战斗界面：生命/灵力/技能/Boss 血条/中央讯息/暂停/死亡/胜利

const GOLD := Color(0.95, 0.78, 0.35)
const GOLD_DIM := Color(0.62, 0.5, 0.25)

var player: Player
var respawn_callback: Callable
var restart_callback: Callable

var _root: Control
var _hp_fill: ColorRect
var _hp_ghost: ColorRect
var _hp_w := 360.0
var _energy_fill: ColorRect
var _energy_w := 280.0
var _skill_panel: Panel
var _skill_fill: ColorRect
var _skill_label: Label
var _skill2_fill: ColorRect
var _skill2_label: Label
var _boss_box: Control
var _boss_fill: ColorRect
var _boss_ghost: ColorRect
var _boss_w := 780.0
var _msg_label: Label
var _vignette_mat: ShaderMaterial
var _overlay: Control = null
var _paused := false
var _ended := false
var _hp_ratio := 1.0
var _boss_ratio := 1.0
var _combo := 0
var _combo_t := 0.0
var _max_combo := 0
var _combo_label: Label
var _soul_label: Label


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_vignette()
	_build_player_bars()
	_build_boss_bar()
	_build_message()
	_build_counters()
	_build_hints()


func bind_player(p: Player) -> void:
	player = p
	p.hp_changed.connect(_on_hp)
	p.energy_changed.connect(_on_energy)
	p.hit_landed.connect(_on_combo_hit)
	Game.soul_collected.connect(_on_soul)
	_on_hp(p.hp, p.MAX_HP)
	_on_energy(p.energy, p.MAX_ENERGY)


# ---------------------------------------------------------------- 构建

func _build_vignette() -> void:
	var v := ColorRect.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette_mat = ShaderMaterial.new()
	_vignette_mat.shader = load("res://shaders/vignette.gdshader")
	v.material = _vignette_mat
	_root.add_child(v)


func _panel_style(border: Color, bg := Color(0.01, 0.04, 0.06, 0.78)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	return sb


func _build_player_bars() -> void:
	# AI 头像（金框）
	var face := Game.tex("res://art/portrait_nezha.png")
	var bar_x := 36.0
	if face:
		bar_x = 132.0
		var frame := Panel.new()
		frame.position = Vector2(30, 24)
		frame.size = Vector2(90, 90)
		var fsb := _panel_style(GOLD, Color(0.02, 0.05, 0.07, 0.9))
		fsb.set_border_width_all(2)
		frame.add_theme_stylebox_override("panel", fsb)
		_root.add_child(frame)
		var img := TextureRect.new()
		img.texture = face
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		img.position = Vector2(3, 3)
		img.size = Vector2(84, 84)
		frame.add_child(img)
	# 名牌
	var name_lbl := Label.new()
	name_lbl.text = "哪 吒"
	name_lbl.position = Vector2(bar_x, 18)
	name_lbl.add_theme_font_size_override("font_size", 30)
	name_lbl.add_theme_color_override("font_color", GOLD)
	name_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	name_lbl.add_theme_constant_override("shadow_offset_y", 2)
	_root.add_child(name_lbl)

	# 生命条
	var hp_bg := Panel.new()
	hp_bg.position = Vector2(bar_x, 62)
	hp_bg.size = Vector2(_hp_w + 8, 26)
	hp_bg.add_theme_stylebox_override("panel", _panel_style(GOLD_DIM))
	_root.add_child(hp_bg)
	_hp_ghost = ColorRect.new()
	_hp_ghost.position = Vector2(4, 4)
	_hp_ghost.size = Vector2(_hp_w, 18)
	_hp_ghost.color = Color(1.0, 0.9, 0.8, 0.55)
	hp_bg.add_child(_hp_ghost)
	_hp_fill = ColorRect.new()
	_hp_fill.position = Vector2(4, 4)
	_hp_fill.size = Vector2(_hp_w, 18)
	_hp_fill.color = Color(0.85, 0.18, 0.2)
	hp_bg.add_child(_hp_fill)

	# 灵力条
	var en_bg := Panel.new()
	en_bg.position = Vector2(bar_x, 94)
	en_bg.size = Vector2(_energy_w + 8, 18)
	en_bg.add_theme_stylebox_override("panel",
		_panel_style(Color(0.3, 0.55, 0.6)))
	_root.add_child(en_bg)
	_energy_fill = ColorRect.new()
	_energy_fill.position = Vector2(4, 4)
	_energy_fill.size = Vector2(_energy_w * 0.3, 10)
	_energy_fill.color = Color(0.3, 0.85, 0.85)
	en_bg.add_child(_energy_fill)

	# 技能图标：三昧真火
	_skill_panel = Panel.new()
	_skill_panel.position = Vector2(bar_x, 126)
	_skill_panel.size = Vector2(58, 58)
	_skill_panel.add_theme_stylebox_override("panel", _panel_style(GOLD_DIM))
	_root.add_child(_skill_panel)
	_skill_fill = ColorRect.new()
	_skill_fill.position = Vector2(3, 55)
	_skill_fill.size = Vector2(52, 0)
	_skill_fill.color = Color(1.0, 0.5, 0.1, 0.35)
	_skill_panel.add_child(_skill_fill)
	_skill_label = Label.new()
	_skill_label.text = "焚"
	_skill_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_skill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skill_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_skill_label.add_theme_font_size_override("font_size", 30)
	_skill_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_skill_panel.add_child(_skill_label)
	var key_lbl := Label.new()
	key_lbl.text = "Q"
	key_lbl.position = Vector2(40, 38)
	key_lbl.add_theme_font_size_override("font_size", 14)
	key_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0.8))
	_skill_panel.add_child(key_lbl)

	# 技能图标：乾坤圈
	var panel2 := Panel.new()
	panel2.position = Vector2(bar_x + 68, 126)
	panel2.size = Vector2(58, 58)
	panel2.add_theme_stylebox_override("panel", _panel_style(GOLD_DIM))
	_root.add_child(panel2)
	_skill2_fill = ColorRect.new()
	_skill2_fill.position = Vector2(3, 55)
	_skill2_fill.size = Vector2(52, 0)
	_skill2_fill.color = Color(0.95, 0.75, 0.3, 0.35)
	panel2.add_child(_skill2_fill)
	_skill2_label = Label.new()
	_skill2_label.text = "环"
	_skill2_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_skill2_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skill2_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_skill2_label.add_theme_font_size_override("font_size", 30)
	_skill2_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	panel2.add_child(_skill2_label)
	var key_lbl2 := Label.new()
	key_lbl2.text = "E"
	key_lbl2.position = Vector2(40, 38)
	key_lbl2.add_theme_font_size_override("font_size", 14)
	key_lbl2.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0.8))
	panel2.add_child(key_lbl2)


func _build_boss_bar() -> void:
	_boss_box = Control.new()
	_boss_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_boss_box.anchor_top = 1.0
	_boss_box.anchor_bottom = 1.0
	_boss_box.position = Vector2(0, 0)
	_boss_box.visible = false
	_root.add_child(_boss_box)

	var name_lbl := Label.new()
	name_lbl.text = "归 墟 之 喉 · 渊 狱 兽"
	name_lbl.position = Vector2(-_boss_w / 2.0, -96)
	name_lbl.size = Vector2(_boss_w, 30)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 26)
	name_lbl.add_theme_color_override("font_color", Color(0.85, 0.5, 1.0))
	name_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	name_lbl.add_theme_constant_override("shadow_offset_y", 2)
	_boss_box.add_child(name_lbl)

	# Boss 头像（紫框，血条左侧）
	var bface := Game.tex("res://art/portrait_boss.png")
	if bface:
		var frame := Panel.new()
		frame.position = Vector2(-_boss_w / 2.0 - 92, -104)
		frame.size = Vector2(76, 76)
		var fsb := _panel_style(Color(0.7, 0.4, 0.95),
			Color(0.04, 0.02, 0.07, 0.9))
		fsb.set_border_width_all(2)
		frame.add_theme_stylebox_override("panel", fsb)
		_boss_box.add_child(frame)
		var img := TextureRect.new()
		img.texture = bface
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		img.position = Vector2(3, 3)
		img.size = Vector2(70, 70)
		frame.add_child(img)

	var bg := Panel.new()
	bg.position = Vector2(-_boss_w / 2.0 - 4, -58)
	bg.size = Vector2(_boss_w + 8, 24)
	bg.add_theme_stylebox_override("panel",
		_panel_style(Color(0.5, 0.3, 0.65)))
	_boss_box.add_child(bg)
	_boss_ghost = ColorRect.new()
	_boss_ghost.position = Vector2(4, 4)
	_boss_ghost.size = Vector2(_boss_w, 16)
	_boss_ghost.color = Color(1.0, 0.85, 0.9, 0.5)
	bg.add_child(_boss_ghost)
	_boss_fill = ColorRect.new()
	_boss_fill.position = Vector2(4, 4)
	_boss_fill.size = Vector2(_boss_w, 16)
	_boss_fill.color = Color(0.62, 0.2, 0.85)
	bg.add_child(_boss_fill)


func _build_message() -> void:
	_msg_label = Label.new()
	_msg_label.set_anchors_preset(Control.PRESET_CENTER)
	_msg_label.anchor_top = 0.3
	_msg_label.anchor_bottom = 0.3
	_msg_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg_label.add_theme_font_size_override("font_size", 54)
	_msg_label.add_theme_color_override("font_color", GOLD)
	_msg_label.add_theme_color_override("font_shadow_color",
		Color(0.6, 0.2, 0.0, 0.5))
	_msg_label.add_theme_constant_override("shadow_offset_y", 4)
	_msg_label.modulate.a = 0.0
	_root.add_child(_msg_label)


func _build_counters() -> void:
	# 连击计数（右上）
	_combo_label = Label.new()
	_combo_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_combo_label.position = Vector2(-330, 96)
	_combo_label.size = Vector2(290, 60)
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_combo_label.add_theme_font_size_override("font_size", 42)
	_combo_label.add_theme_color_override("font_color", GOLD)
	_combo_label.add_theme_color_override("font_shadow_color",
		Color(0, 0, 0, 0.8))
	_combo_label.add_theme_constant_override("shadow_offset_y", 3)
	_combo_label.visible = false
	_root.add_child(_combo_label)
	# 龙魂残片计数（右上角）
	_soul_label = Label.new()
	_soul_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_soul_label.position = Vector2(-330, 26)
	_soul_label.size = Vector2(290, 40)
	_soul_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_soul_label.text = "龙魂残片　0 / 3"
	_soul_label.add_theme_font_size_override("font_size", 22)
	_soul_label.add_theme_color_override("font_color",
		Color(1.0, 0.82, 0.35, 0.75))
	_root.add_child(_soul_label)


func _on_combo_hit(count: int) -> void:
	_combo += count
	_max_combo = maxi(_max_combo, _combo)
	_combo_t = 2.4
	_combo_label.text = "连击 ×%d" % _combo
	_combo_label.visible = true
	if _combo >= 12:
		_combo_label.add_theme_color_override("font_color",
			Color(1.0, 0.4, 0.2))
	elif _combo >= 6:
		_combo_label.add_theme_color_override("font_color",
			Color(1.0, 0.62, 0.2))
	else:
		_combo_label.add_theme_color_override("font_color", GOLD)
	_combo_label.modulate = Color(1.5, 1.5, 1.5)
	var tw := _combo_label.create_tween()
	tw.tween_property(_combo_label, "modulate", Color.WHITE, 0.2)


func _on_soul(total: int) -> void:
	_soul_label.text = "龙魂残片　%d / 3" % total
	show_message("拾得龙魂残片 %d / 3" % total, 1.6, 36)
	_soul_label.modulate = Color(1.8, 1.8, 1.8)
	var tw := _soul_label.create_tween()
	tw.tween_property(_soul_label, "modulate", Color.WHITE, 0.5)


func _build_hints() -> void:
	var lbl := Label.new()
	lbl.text = "A/D 移动　空格 跳跃　Shift 冲刺　J 连击　K 重击/空中下砸　E 乾坤圈　Q 三昧真火　Esc 暂停"
	lbl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	lbl.position = Vector2(36, -44)
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(0.6, 0.7, 0.7, 0.45))
	_root.add_child(lbl)


# ---------------------------------------------------------------- 更新

func _process(delta: float) -> void:
	# 连击衰减
	if _combo > 0 and not get_tree().paused:
		_combo_t -= delta
		if _combo_t <= 0.0:
			_combo = 0
			_combo_label.visible = false
	# 残影血条缓降
	_hp_ghost.size.x = lerpf(_hp_ghost.size.x, _hp_ratio * _hp_w, 3.0 * delta)
	_boss_ghost.size.x = lerpf(_boss_ghost.size.x, _boss_ratio * _boss_w,
		3.0 * delta)
	# 技能就绪状态
	if player and is_instance_valid(player):
		var ready := player.energy >= player.SKILL_COST
		_skill_label.add_theme_color_override("font_color",
			Color(1.0, 0.65, 0.2) if ready else Color(0.5, 0.5, 0.5))
		var ratio := clampf(player.energy / player.SKILL_COST, 0.0, 1.0)
		_skill_fill.size = Vector2(52, 52 * ratio)
		_skill_fill.position.y = 3 + 52 * (1.0 - ratio)
		_skill_fill.color = Color(1.0, 0.55, 0.1, 0.5 if ready else 0.25)
		# 乾坤圈：飞出期间不可用
		var ready2: bool = player.energy >= player.SKILL2_COST \
			and not player._ring_out
		_skill2_label.add_theme_color_override("font_color",
			Color(0.95, 0.78, 0.35) if ready2 else Color(0.5, 0.5, 0.5))
		var ratio2 := clampf(player.energy / player.SKILL2_COST, 0.0, 1.0)
		if player._ring_out:
			ratio2 = 0.0
		_skill2_fill.size = Vector2(52, 52 * ratio2)
		_skill2_fill.position.y = 3 + 52 * (1.0 - ratio2)
		_skill2_fill.color = Color(0.95, 0.75, 0.3, 0.5 if ready2 else 0.25)


func _on_hp(hp: float, max_hp: float) -> void:
	_hp_ratio = hp / max_hp
	_hp_fill.size.x = _hp_ratio * _hp_w
	_vignette_mat.set_shader_parameter("low_hp",
		clampf(1.0 - _hp_ratio / 0.35, 0.0, 1.0))


func _on_energy(energy: float, max_energy: float) -> void:
	_energy_fill.size.x = energy / max_energy * _energy_w


func show_boss_bar(visible_v: bool) -> void:
	_boss_box.visible = visible_v


func on_boss_hp(hp: float, max_hp: float) -> void:
	_boss_ratio = hp / max_hp
	_boss_fill.size.x = _boss_ratio * _boss_w


func show_message(text: String, dur := 2.2, size := 54) -> void:
	_msg_label.text = text
	_msg_label.add_theme_font_size_override("font_size", size)
	var tw := _msg_label.create_tween()
	tw.tween_property(_msg_label, "modulate:a", 1.0, 0.4)
	tw.tween_interval(dur)
	tw.tween_property(_msg_label, "modulate:a", 0.0, 0.8)


# ---------------------------------------------------------------- 暂停 / 结算

func _input(event: InputEvent) -> void:
	if _ended:
		return
	if event.is_action_pressed("pause"):
		if _paused:
			_unpause()
		else:
			_show_pause()


func _make_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(340, 58)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 26)
	btn.add_theme_color_override("font_color", Color(0.85, 0.85, 0.82))
	btn.add_theme_color_override("font_hover_color", GOLD)
	var sb := _panel_style(GOLD_DIM, Color(0.02, 0.07, 0.10, 0.85))
	sb.set_content_margin_all(10)
	btn.add_theme_stylebox_override("normal", sb)
	var sbh := sb.duplicate() as StyleBoxFlat
	sbh.border_color = GOLD
	sbh.set_border_width_all(2)
	sbh.bg_color = Color(0.05, 0.13, 0.16, 0.95)
	btn.add_theme_stylebox_override("hover", sbh)
	btn.add_theme_stylebox_override("pressed", sbh)
	btn.mouse_entered.connect(func() -> void: Game.play_sfx("ui", -10.0, 1.3))
	return btn


func _show_overlay(title: String, title_color: Color, sub: String,
		buttons: Array) -> void:
	_clear_overlay()
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0, 0.01, 0.02, 0.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)
	var dtw := dim.create_tween()
	dtw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	dtw.tween_property(dim, "color:a", 0.72, 0.4)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 20)
	_overlay.add_child(box)

	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 72)
	title_lbl.add_theme_color_override("font_color", title_color)
	title_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	title_lbl.add_theme_constant_override("shadow_offset_y", 4)
	box.add_child(title_lbl)

	if sub != "":
		var sub_lbl := Label.new()
		sub_lbl.text = sub
		sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub_lbl.add_theme_font_size_override("font_size", 24)
		sub_lbl.add_theme_color_override("font_color",
			Color(0.75, 0.8, 0.8, 0.85))
		box.add_child(sub_lbl)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	box.add_child(spacer)

	for b: Array in buttons:
		var btn := _make_button(b[0])
		btn.pressed.connect(b[1])
		var center := CenterContainer.new()
		center.add_child(btn)
		box.add_child(center)

	box.modulate.a = 0.0
	var btw := box.create_tween()
	btw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	btw.tween_property(box, "modulate:a", 1.0, 0.45).set_delay(0.15)


func _clear_overlay() -> void:
	if _overlay:
		_overlay.queue_free()
		_overlay = null


func _show_pause() -> void:
	_paused = true
	get_tree().paused = true
	Game.play_sfx("ui", -6.0)
	_show_overlay("暂 歇", Color(0.7, 0.85, 0.85), "潮汐暂止，渊兽仍在深处蛰伏……", [
		["继 续", _unpause],
		["重新挑战本关", func() -> void:
			get_tree().paused = false
			restart_callback.call()],
		["返回主菜单", func() -> void:
			Game.change_scene("res://scenes/main_menu.tscn")],
	])


func _unpause() -> void:
	_paused = false
	get_tree().paused = false
	_clear_overlay()
	Game.play_sfx("ui", -8.0, 0.8)


func show_death() -> void:
	_ended = true
	await get_tree().create_timer(1.1, false).timeout
	_ended = false
	_show_overlay("命 陨 潮 渊", Color(0.9, 0.3, 0.3),
		"归墟的暗流吞没了你……但莲花不灭，轮回不止。", [
		["莲 台 重 生", func() -> void:
			_clear_overlay()
			respawn_callback.call()],
		["返回主菜单", func() -> void:
			Game.change_scene("res://scenes/main_menu.tscn")],
	])


func show_victory() -> void:
	_ended = true
	var mins := int(Game.run_time) / 60
	var secs := int(Game.run_time) % 60
	_show_overlay("渊 兽 镇 压", GOLD,
		"碎潮回廊的秩序暂得安宁。\n用时 %d 分 %02d 秒 · 陨落 %d 次 · 最高连击 ×%d · 龙魂残片 %d/3\n—— 第二章 · 龙宫深狱 · 待续 ——"
			% [mins, secs, Game.death_count, _max_combo, Game.souls], [
		["返回主菜单", func() -> void:
			Game.change_scene("res://scenes/main_menu.tscn")],
	])
