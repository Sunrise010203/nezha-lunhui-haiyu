class_name TideStele
extends StaticBody3D
## 潮纹碑：被「卸」弹回来的潮弹击中会亮起。
## 只认 was_reflected 的弹（齐射的不算），所以必须真的"弹"过去，而不是拿引潮的弹糊上去。

var lit := false
var reward_count := 1
var _glyph: MeshInstance3D
var _light: OmniLight3D
var _mat: StandardMaterial3D
var _reward_taken := false


func _ready() -> void:
	add_to_group("tide_stele")
	collision_layer = 1
	collision_mask = 0
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.1, 2.6, 0.6)
	col.shape = box
	col.position.y = 1.3
	add_child(col)

	# 沉骨碑身：底座 + 收分的碑体 + 碑帽。原来是一整块亮骨白方盒，
	# 在玉青暗场里读成"黄色积木"，现在压暗到 0.34 并把碑体做窄、做收分。
	var bone := Game.std_mat(Color(0.30, 0.34, 0.31), Color(0.01, 0.03, 0.03),
		0.04, 0.95)
	var base := BoxMesh.new()
	base.size = Vector3(1.15, 0.34, 0.78)
	Game.add_mesh(self, base, bone, Vector3(0, 0.17, 0))
	var body := BoxMesh.new()
	body.size = Vector3(0.72, 2.0, 0.34)
	Game.add_mesh(self, body, bone, Vector3(0, 1.34, 0))
	var cap := BoxMesh.new()
	cap.size = Vector3(0.94, 0.18, 0.52)
	Game.add_mesh(self, cap, bone, Vector3(0, 2.43, 0))
	var foot := BoxMesh.new()
	foot.size = Vector3(0.62, 0.22, 0.46)
	Game.add_mesh(self, foot, bone, Vector3(0, 0.44, 0))

	# 碑面刻痕：三道竖纹 + 一道横纹，未点亮时几乎看不见，点亮才是整碑发青
	_mat = Game.std_mat(Color(0.16, 0.34, 0.32), Color(0.25, 0.85, 0.78),
		0.10, 0.25)
	var slat := BoxMesh.new()
	slat.size = Vector3(0.055, 1.25, 0.035)
	_glyph = Game.add_mesh(self, slat, _mat, Vector3(0, 1.5, 0.185))
	var glyph_root := _glyph
	for dx in [-0.19, 0.19]:
		var extra := MeshInstance3D.new()
		extra.mesh = slat
		extra.material_override = _mat
		extra.position = Vector3(dx, 0.0, 0.0)
		glyph_root.add_child(extra)
	var bar := BoxMesh.new()
	bar.size = Vector3(0.46, 0.055, 0.035)
	var bar_mi := MeshInstance3D.new()
	bar_mi.mesh = bar
	bar_mi.material_override = _mat
	bar_mi.position = Vector3(0, 0.52, 0.0)
	glyph_root.add_child(bar_mi)

	_light = OmniLight3D.new()
	_light.light_color = Color(0.35, 0.95, 0.85)
	_light.light_energy = 0.0
	_light.omni_range = 4.5
	_light.position = Vector3(0, 1.4, 0.8)
	_light.shadow_enabled = false
	add_child(_light)
	Game.tune_small_light(_light, 0.0, 4.5)


func light_up() -> void:
	if lit:
		return
	lit = true
	Game.play_sfx("rune_gain", -3.0, 0.8)
	Game.burst(get_parent(), global_position + Vector3(0, 1.4, 0.4),
		Color(0.4, 0.95, 0.88), 26, 5.0, 0.08, 0.6)
	Game.spawn_dmg_text(get_parent(), global_position + Vector3(0, 2.8, 0),
		"潮纹碑 · 亮", Color(0.55, 0.95, 0.88), true)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_light, "light_energy", 2.2, 0.35)
	if _mat:
		tw.tween_property(_mat, "emission_energy_multiplier", 3.2, 0.35)
	tw.tween_property(_glyph, "scale", Vector3(1.06, 1.06, 1.0), 0.2)
	if not _reward_taken:
		_reward_taken = true
		# 每座碑只掉 1 颗灵珠：三碑全亮 3 颗，加上关卡手动摆的 7 颗，
		# 正好落在第三关沿用下来的"灵珠 6–8"区间附近，不至于把灵力经济打崩。
		for i in reward_count:
			var p := Pickup.new()
			p.kind = Pickup.Kind.ENERGY
			p.position = global_position + Vector3(randf_range(-0.4, 0.4),
				1.2 + randf_range(0.0, 0.6), 0)
			get_parent().add_child(p)
		# 亮碑要"摸得到"的收益：回血 + 补 1 格潮纹。
		# 否则玩家只会把弹反当花架子，反正不用也能过。
		var pl := get_tree().get_first_node_in_group("player")
		if pl != null and pl.has_method("heal"):
			pl.call("heal", 18.0)
			if pl.get("tide_runes") != null:
				pl.set("tide_runes", minf(float(pl.get("tide_runes")) + 1.0,
					float(pl.TIDE_RUNE_MAX)))
				if pl.has_signal("runes_changed"):
					pl.emit_signal("runes_changed", pl.get("tide_runes"),
						pl.TIDE_RUNE_MAX)
			Game.spawn_dmg_text(get_parent(), pl.global_position + Vector3(0, 2.1, 0),
				"+18", Color(0.55, 0.95, 0.7), false)
