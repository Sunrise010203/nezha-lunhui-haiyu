class_name HUD
extends CanvasLayer
## 战斗界面：生命/灵力/技能/Boss 血条/中央讯息/暂停/死亡/胜利

const GOLD := Color(0.95, 0.78, 0.35)
const GOLD_DIM := Color(0.62, 0.5, 0.25)
const JADE := Color(0.42, 0.94, 0.86)
const JADE_DIM := Color(0.24, 0.52, 0.48)

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
var _skill3_fill: ColorRect
var _skill3_label: Label
var _skill2_lock: Label
var _skill3_lock: Label
var _skill_icon := false
var _skill2_icon := false
var _skill3_icon := false
var _skill2_panel: Panel
var _skill3_panel: Panel
# 第四章：定潮槽
var _tide_panel: Panel = null
var _tide_label: Label = null
var _tide_pips: Array[ColorRect] = []
var _boss_box: Control
var _boss_fill: ColorRect
var _boss_ghost: ColorRect
var _boss_w := 780.0
var _boss_name_lbl: Label = null
var _boss_portrait: Control = null
var _boss_portrait_img: TextureRect = null
var _boss_bg: Panel = null
var _boss_frame: Panel = null
var _msg_label: Label
var _vignette_mat: ShaderMaterial
var _overlay: Control = null
## 当前面板种类："" / "pause" / "death" / "campaign_death" / "victory"。
## 用它而不是"有没有面板"来判断能否 Esc 暂停，否则普通暂停菜单自己都退不掉。
var _overlay_kind := ""
var _paused := false
var _ended := false
var _hp_ratio := 1.0
var _boss_ratio := 1.0
var _combo := 0
var _combo_t := 0.0
var _max_combo := 0
var _combo_label: Label
var _soul_label: Label
var _hint_label: Label
## 灵力恢复说明（"脱战 3 秒后缓慢回复"）
var regen_hint_label: Label = null
var _msg_tween: Tween = null
## 本章龙魂残片总数（由关卡设置）
var soul_total := 3
## 通关结算时显示的章节名（由关卡设置）
var victory_chapter := ""


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
	if Game.tide_unlocked and p.has_signal("runes_changed"):
		p.runes_changed.connect(_on_runes)
		_on_runes(p.tide_runes, p.TIDE_RUNE_MAX)
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


func _apply_skill_icon(panel: Panel, path: String) -> bool:
	## 技能图标：有 AI 图就作为面板底图拉伸铺满，没有就返回 false，回退到汉字。
	## 用 StyleBoxTexture 而不是 TextureRect：TextureRect 在小尺寸下可能按原图 1:1
	## 只画出左上角（图标只剩金边角），StyleBoxTexture 会严格铺满 58×58。
	var tex := Game.tex(path)
	if tex == null:
		return false
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left = 0
	sb.texture_margin_right = 0
	sb.texture_margin_top = 0
	sb.texture_margin_bottom = 0
	sb.content_margin_left = 0
	sb.content_margin_right = 0
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	panel.add_theme_stylebox_override("panel", sb)
	return true


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

	# 灵力恢复说明：让"脱战后会慢慢回"这条规则在屏幕上可见，
	# 否则玩家只会以为灵力是一次性资源（HUD 说明，不改任何数值）。
	var regen_lbl := Label.new()
	regen_lbl.text = "脱战 3 秒后缓慢回复"
	regen_lbl.position = Vector2(bar_x + _energy_w + 22, 92)
	regen_lbl.add_theme_font_size_override("font_size", 14)
	regen_lbl.add_theme_color_override("font_color", Color(0.55, 0.74, 0.74, 0.6))
	regen_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	regen_lbl.add_theme_constant_override("shadow_offset_y", 1)
	regen_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(regen_lbl)
	regen_hint_label = regen_lbl

	# 技能图标：三昧真火
	_skill_panel = Panel.new()
	_skill_panel.position = Vector2(bar_x, 126)
	_skill_panel.size = Vector2(58, 58)
	_skill_panel.add_theme_stylebox_override("panel", _panel_style(GOLD_DIM))
	_root.add_child(_skill_panel)
	_skill_icon = _apply_skill_icon(_skill_panel, "res://art/icon_flame.png")
	_skill_fill = ColorRect.new()
	_skill_fill.position = Vector2(3, 54)
	_skill_fill.size = Vector2(52, 4)
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
	key_lbl.add_theme_constant_override("outline_size", 4)
	key_lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	_skill_panel.add_child(key_lbl)

	# 技能图标：乾坤圈
	var panel2 := Panel.new()
	panel2.position = Vector2(bar_x + 68, 126)
	panel2.size = Vector2(58, 58)
	panel2.add_theme_stylebox_override("panel", _panel_style(GOLD_DIM))
	_root.add_child(panel2)
	_skill2_panel = panel2
	_skill2_icon = _apply_skill_icon(panel2, "res://art/icon_ring.png")
	_skill2_fill = ColorRect.new()
	_skill2_fill.position = Vector2(3, 54)
	_skill2_fill.size = Vector2(52, 4)
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
	key_lbl2.add_theme_constant_override("outline_size", 4)
	key_lbl2.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	panel2.add_child(key_lbl2)

	# 技能图标：风火轮（闯关模式收集龙魂解锁）
	var panel3 := Panel.new()
	panel3.position = Vector2(bar_x + 136, 126)
	panel3.size = Vector2(58, 58)
	panel3.add_theme_stylebox_override("panel", _panel_style(GOLD_DIM))
	_root.add_child(panel3)
	_skill3_panel = panel3
	_skill3_icon = _apply_skill_icon(panel3, "res://art/icon_wheel.png")
	_skill3_fill = ColorRect.new()
	_skill3_fill.position = Vector2(3, 54)
	_skill3_fill.size = Vector2(52, 4)
	_skill3_fill.color = Color(1.0, 0.35, 0.15, 0.35)
	panel3.add_child(_skill3_fill)
	_skill3_label = Label.new()
	_skill3_label.text = "轮"
	_skill3_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_skill3_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skill3_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_skill3_label.add_theme_font_size_override("font_size", 30)
	_skill3_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	panel3.add_child(_skill3_label)
	var key_lbl3 := Label.new()
	key_lbl3.text = "V"
	key_lbl3.position = Vector2(40, 38)
	key_lbl3.add_theme_font_size_override("font_size", 14)
	key_lbl3.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0.8))
	key_lbl3.add_theme_constant_override("outline_size", 4)
	key_lbl3.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	panel3.add_child(key_lbl3)

	# 未解锁的锁标（闯关模式初始只有 Q）——改用占位文字，避免和图标叠字
	_skill2_lock = _make_lock_label()
	_skill2_lock.visible = false
	panel2.add_child(_skill2_lock)
	_skill3_lock = _make_lock_label()
	_skill3_lock.visible = false
	panel3.add_child(_skill3_lock)

	_build_tide_slot(bar_x + 204)


func _build_tide_slot(x: float) -> void:
	## 第四章：定潮槽。三格潮纹从下往上填（第三章设计里约定"只由打中赚"，
	## 所以这一格必须一眼看出还剩几次弹反容错）。
	_tide_panel = Panel.new()
	_tide_panel.position = Vector2(x, 126)
	_tide_panel.size = Vector2(58, 58)
	_tide_panel.add_theme_stylebox_override("panel", _panel_style(JADE_DIM))
	_tide_panel.visible = Game.tide_unlocked
	_root.add_child(_tide_panel)

	_tide_label = Label.new()
	_tide_label.text = "潮"
	_tide_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tide_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tide_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tide_label.add_theme_font_size_override("font_size", 30)
	_tide_label.add_theme_color_override("font_color", JADE)
	_tide_panel.add_child(_tide_label)

	var key_lbl := Label.new()
	key_lbl.text = "G"
	key_lbl.position = Vector2(40, 38)
	key_lbl.add_theme_font_size_override("font_size", 14)
	key_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0.8))
	key_lbl.add_theme_constant_override("outline_size", 4)
	key_lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	_tide_panel.add_child(key_lbl)

	# 三格潮纹：横向排列在槽底，亮=可用，暗=已花掉
	_tide_pips.clear()
	for i in Player.TIDE_RUNE_MAX:
		var pip := ColorRect.new()
		pip.position = Vector2(4 + i * 17, 50)
		pip.size = Vector2(14, 5)
		pip.color = Color(0.30, 0.85, 0.78, 0.25)
		_tide_panel.add_child(pip)
		_tide_pips.append(pip)
	_tide_fill_pips(Player.TIDE_RUNE_MAX, Player.TIDE_RUNE_MAX)


func _tide_fill_pips(cur: float, mx: float) -> void:
	var whole := int(floor(cur))
	var frac := cur - float(whole)
	for i in _tide_pips.size():
		var pip: ColorRect = _tide_pips[i]
		if i < whole:
			pip.color = Color(0.35, 0.95, 0.88, 0.95)
		elif i == whole and frac > 0.02:
			pip.color = Color(0.35, 0.95, 0.88, 0.35 + 0.55 * frac)
		else:
			pip.color = Color(0.30, 0.85, 0.78, 0.18)
	if _tide_label:
		var ready := cur >= 1.0
		_tide_label.add_theme_color_override("font_color",
			JADE if ready else Color(0.45, 0.5, 0.5))
	if _tide_panel:
		_tide_panel.modulate = Color.WHITE if cur >= 1.0 else \
			Color(0.7, 0.75, 0.75)


func _on_runes(cur: float, mx: float) -> void:
	_tide_fill_pips(cur, mx)
	if _tide_panel and cur < float(mx):
		var tw := _tide_panel.create_tween()
		tw.tween_property(_tide_panel, "scale", Vector2(1.06, 1.06), 0.07)
		tw.tween_property(_tide_panel, "scale", Vector2.ONE, 0.12)


func _make_lock_label() -> Label:
	var l := Label.new()
	l.text = "锁"
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6, 0.9))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


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
	_boss_name_lbl = name_lbl

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
		_boss_portrait = frame
		_boss_frame = frame
		var img := TextureRect.new()
		img.texture = bface
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		img.position = Vector2(3, 3)
		img.size = Vector2(70, 70)
		frame.add_child(img)
		_boss_portrait_img = img

	var bg := Panel.new()
	bg.position = Vector2(-_boss_w / 2.0 - 4, -58)
	bg.size = Vector2(_boss_w + 8, 24)
	bg.add_theme_stylebox_override("panel",
		_panel_style(Color(0.5, 0.3, 0.65)))
	_boss_box.add_child(bg)
	_boss_bg = bg
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
	_soul_label.text = "龙魂残片　0 / %d" % soul_total
	_soul_label.add_theme_font_size_override("font_size", 22)
	_soul_label.add_theme_color_override("font_color",
		Color(1.0, 0.82, 0.35, 0.75))
	# 右上角经常压在亮天空/海面上：加描边 + 阴影，保证 3:1 以上可读
	_soul_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	_soul_label.add_theme_constant_override("shadow_offset_y", 2)
	_soul_label.add_theme_constant_override("outline_size", 4)
	_soul_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
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
	_soul_label.text = "龙魂残片　%d / %d" % [total, soul_total]
	show_message("拾得龙魂残片 %d / %d" % [total, soul_total], 1.6, 36)
	_soul_label.modulate = Color(1.8, 1.8, 1.8)
	var tw := _soul_label.create_tween()
	tw.tween_property(_soul_label, "modulate", Color.WHITE, 0.5)


func _build_hints() -> void:
	# 底部操作条：先铺一条低透明度渐隐底，避免文字直接压在亮水面/石台上
	var strip := ColorRect.new()
	strip.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	strip.offset_top = -58
	strip.offset_bottom = 0
	strip.color = Color(0.01, 0.03, 0.04, 0.38)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(strip)
	var line := ColorRect.new()
	line.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	line.offset_top = -58
	line.offset_bottom = -57
	line.color = Color(0.95, 0.78, 0.35, 0.22)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(line)

	var lbl := Label.new()
	lbl.text = "A/D 移动　空格 跳跃　Shift 冲刺　J 连击　K 重击　E 乾坤圈　Q 真火　V 风火轮　F 混天绫　Esc 暂停"
	if Game.tide_unlocked:
		# 第四章独有：写在最前面，因为这章的新手引导就是它
		lbl.text = "G 定潮（短按弹反 / 长按引潮）　" + lbl.text
	lbl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	lbl.position = Vector2(36, -44)
	lbl.add_theme_font_size_override("font_size", 19)
	# 原来 16px / alpha 0.45，实测有效对比度仅 1.6:1，基本读不清
	lbl.add_theme_color_override("font_color", Color(0.72, 0.82, 0.82, 0.78))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	_hint_label = lbl
	_root.add_child(lbl)


func show_hints(v: bool) -> void:
	## Boss 战期间隐藏底部操作提示，避免和 Boss 血条重叠
	if _hint_label:
		_hint_label.visible = v


func set_soul_total(n: int) -> void:
	soul_total = maxi(n, 1)
	if _soul_label:
		_soul_label.text = "龙魂残片　%d / %d" % [Game.souls, soul_total]


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
		var q_on := Game.has_skill("Q")
		var e_on := Game.has_skill("E")
		var v_on := Game.has_skill("V")
		_skill2_lock.visible = false
		_skill3_lock.visible = false
		# 有 AI 图标时不再叠汉字；未解锁才显示"锁"
		_skill_label.text = "" if (q_on and _skill_icon) else ("焚" if q_on else "锁")
		_skill2_label.text = "" if (e_on and _skill2_icon) else ("环" if e_on else "锁")
		_skill3_label.text = "" if (v_on and _skill3_icon) else ("轮" if v_on else "锁")
		var ready := q_on and player.energy >= player.SKILL_COST
		if _skill_icon:
			_skill_panel.modulate = Color.WHITE if ready else \
				(Color(0.7, 0.7, 0.7) if q_on else Color(0.35, 0.35, 0.35, 0.9))
		_skill_label.add_theme_color_override("font_color",
			Color(0.5, 0.5, 0.5) if not q_on else
			(Color(1.0, 0.65, 0.2) if ready else Color(0.5, 0.5, 0.5)))
		var ratio := clampf(player.energy / player.SKILL_COST, 0.0, 1.0)
		_skill_fill.size = Vector2(52 * ratio, 4)
		_skill_fill.position.y = 54
		_skill_fill.color = Color(1.0, 0.55, 0.1, 0.9 if ready else 0.35)
		# 乾坤圈：未解锁 / 飞出期间不可用
		var ready2: bool = e_on and player.energy >= player.SKILL2_COST \
			and not player._ring_out
		if _skill2_icon:
			_skill2_panel.modulate = Color.WHITE if ready2 else \
				(Color(0.7, 0.7, 0.7) if e_on else Color(0.35, 0.35, 0.35, 0.9))
		_skill2_label.add_theme_color_override("font_color",
			Color(0.5, 0.5, 0.5) if not e_on else
			(Color(0.95, 0.78, 0.35) if ready2 else Color(0.5, 0.5, 0.5)))
		var ratio2 := clampf(player.energy / player.SKILL2_COST, 0.0, 1.0)
		if player._ring_charging:
			# 蓄力中：图标按蓄力进度填充（金→亮）
			ratio2 = clampf(player._ring_charge / player.RING_CHARGE_MAX, 0.0, 1.0)
			_skill2_label.add_theme_color_override("font_color",
				Color(1.0, 0.85, 0.35))
		elif player._ring_out or not e_on:
			ratio2 = 0.0
		_skill2_fill.size = Vector2(52 * ratio2, 4)
		_skill2_fill.position.y = 54
		_skill2_fill.color = Color(0.95, 0.75, 0.3, 0.9 if ready2 else 0.35)
		# 风火轮：未解锁 / 腾空强化窗口内显示剩余时间比例
		var ready3: bool = v_on and player.energy >= player.SKILL3_COST \
			and player.wheel_t <= 0.0
		if _skill3_icon:
			_skill3_panel.modulate = Color.WHITE if ready3 else \
				(Color(0.7, 0.7, 0.7) if v_on else Color(0.35, 0.35, 0.35, 0.9))
		_skill3_label.add_theme_color_override("font_color",
			Color(0.5, 0.5, 0.5) if not v_on else
			(Color(1.0, 0.45, 0.2) if ready3 else Color(0.5, 0.5, 0.5)))
		var ratio3 := clampf(player.energy / player.SKILL3_COST, 0.0, 1.0)
		if player.wheel_t > 0.0:
			ratio3 = clampf(player.wheel_t / player.WHEEL_TIME, 0.0, 1.0)
		if not v_on:
			ratio3 = 0.0
		_skill3_fill.size = Vector2(52 * ratio3, 4)
		_skill3_fill.position.y = 54
		_skill3_fill.color = Color(1.0, 0.4, 0.15, 0.9 if ready3 else 0.35)


func _on_hp(hp: float, max_hp: float) -> void:
	_hp_ratio = hp / max_hp
	_hp_fill.size.x = _hp_ratio * _hp_w
	_vignette_mat.set_shader_parameter("low_hp",
		clampf(1.0 - _hp_ratio / 0.35, 0.0, 1.0))


func _on_energy(energy: float, max_energy: float) -> void:
	_energy_fill.size.x = energy / max_energy * _energy_w


func show_boss_bar(visible_v: bool) -> void:
	_boss_box.visible = visible_v


func set_boss_name(text: String, color := Color(0.85, 0.5, 1.0)) -> void:
	## 每章 Boss 不同：原来名字硬编码成第一章的"归墟之喉"，第二章会显示错
	if _boss_name_lbl:
		_boss_name_lbl.text = text
		_boss_name_lbl.add_theme_color_override("font_color", color)


func set_boss_portrait(path: String) -> void:
	## 传空串 = 本章没有专属头像，隐藏头像框（避免拿第一章的立绘冒充新 Boss）
	var tex := Game.tex(path) if path != "" else null
	if _boss_portrait:
		_boss_portrait.visible = tex != null
	if tex and _boss_portrait_img:
		_boss_portrait_img.texture = tex


func set_boss_theme(fill: Color, frame: Color, name_col: Color) -> void:
	## 每章 Boss 血条配色：第一/二章紫、第三章青紫、第四章玉青
	if _boss_fill:
		_boss_fill.color = fill
	if _boss_ghost:
		_boss_ghost.color = Color(fill.r + 0.38, fill.g + 0.38, fill.b + 0.38, 0.5)
	if _boss_bg:
		_boss_bg.add_theme_stylebox_override("panel", _panel_style(frame))
	if _boss_frame:
		var fsb := _panel_style(frame, Color(0.04, 0.02, 0.07, 0.9))
		fsb.set_border_width_all(2)
		_boss_frame.add_theme_stylebox_override("panel", fsb)
	if _boss_name_lbl:
		_boss_name_lbl.add_theme_color_override("font_color", name_col)


func on_boss_hp(hp: float, max_hp: float) -> void:
	_boss_ratio = hp / max_hp
	_boss_fill.size.x = _boss_ratio * _boss_w


func show_message(text: String, dur := 2.2, size := 54) -> void:
	_msg_label.text = text
	_msg_label.add_theme_font_size_override("font_size", size)
	# 先杀掉上一条消息的 Tween，否则连续消息会互相抢 alpha
	if _msg_tween and _msg_tween.is_valid():
		_msg_tween.kill()
	_msg_tween = _msg_label.create_tween()
	_msg_tween.tween_property(_msg_label, "modulate:a", 1.0, 0.4)
	_msg_tween.tween_interval(dur)
	_msg_tween.tween_property(_msg_label, "modulate:a", 0.0, 0.8)


# ---------------------------------------------------------------- 暂停 / 结算

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if _ended:
		# 死亡/结算面板正在出现（或已出现）：Esc 不再叠暂停菜单
		return
	if _overlay_kind != "" and _overlay_kind != "pause":
		# 死亡/通关面板已经打开，不允许用 Esc 再盖一层
		return
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
		buttons: Array, kind := "generic") -> void:
	_clear_overlay()
	_overlay_kind = kind
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
	_overlay_kind = ""


func overlay_kind() -> String:
	## 供测试与关卡逻辑查询当前面板种类
	return _overlay_kind


func _show_pause() -> void:
	_paused = true
	get_tree().paused = true
	Game.play_sfx("ui", -6.0)
	_show_overlay("暂 歇", Color(0.7, 0.85, 0.85), "潮汐暂止，渊兽仍在深处蛰伏……", [
		["继 续", _unpause],
		["重新挑战本关", func() -> void:
			get_tree().paused = false
			_paused = false
			restart_callback.call()],
		["返回主菜单", func() -> void:
			Game.change_scene("res://scenes/main_menu.tscn")],
	], "pause")


func _unpause() -> void:
	_paused = false
	get_tree().paused = false
	_clear_overlay()
	Game.play_sfx("ui", -8.0, 0.8)


func show_death() -> void:
	## 选关模式：莲台复活。同一时刻只允许一块死亡面板，重复调用直接忽略。
	if _ended or _overlay_kind == "death" or _overlay_kind == "campaign_death":
		return
	_ended = true
	# 死亡面板出现前先解除暂停，避免"暂停中死去 → 面板卡在暂停帧"
	_paused = false
	get_tree().paused = false
	await get_tree().create_timer(1.1, false).timeout
	_ended = false
	_show_overlay("命 陨 潮 渊", Color(0.9, 0.3, 0.3),
		"归墟的暗流吞没了你……但莲花不灭，轮回不止。", [
		["莲 台 重 生", func() -> void:
			_clear_overlay()
			respawn_callback.call()],
		["返回主菜单", func() -> void:
			Game.change_scene("res://scenes/main_menu.tscn")],
	], "death")


func show_campaign_death(chapter_title := "") -> void:
	## 闯关模式死亡：整关刷新，从本章出生点重来（不是莲台复活）
	if _ended or _overlay_kind == "death" or _overlay_kind == "campaign_death":
		return
	_ended = true
	_paused = false
	get_tree().paused = false
	await get_tree().create_timer(1.1, false).timeout
	_ended = false
	var cname := chapter_title if chapter_title != "" else "本 章"
	_show_overlay("命 陨 潮 渊", Color(0.9, 0.3, 0.3),
		"闯关模式：%s\n将从本章出生点重新开始（已解锁技能保留）。" % cname, [
		["重 新 挑 战 本 章", func() -> void:
			_clear_overlay()
			restart_callback.call()],
		["返回主菜单", func() -> void:
			Game.change_scene("res://scenes/main_menu.tscn")],
	], "campaign_death")


func show_victory() -> void:
	if _ended and _overlay_kind == "victory":
		return
	_ended = true
	# 结算优先级最高：先把暂停解除，否则 Tab/暂停中通关会卡死在暂停帧
	_paused = false
	get_tree().paused = false
	var mins := int(Game.run_time) / 60
	var secs := int(Game.run_time) % 60
	_show_overlay("关 卡 通 关", GOLD,
		"%s\n用时 %d 分 %02d 秒 · 陨落 %d 次 · 最高连击 ×%d · 龙魂残片 %d/%d\n—— 可返回选关，挑战另一章 ——"
			% [victory_chapter, mins, secs, Game.death_count, _max_combo,
				Game.souls, soul_total], [
		["返 回 选 关", func() -> void:
			Game.change_scene("res://scenes/level_select.tscn")],
		["返 回 主 菜 单", func() -> void:
			Game.change_scene("res://scenes/main_menu.tscn")],
	], "victory")
