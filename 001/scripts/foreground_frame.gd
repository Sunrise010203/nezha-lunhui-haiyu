class_name ForegroundFrame
extends Control
## P1 §4.4 前景框景（2D 遮幅）
## 贴在相机前、只压画面四角的暗色藤蔓/岩块剪影：
## - 不参与 3D 碰撞/光照/阴影，所以永远不会挡住角色和平台；
## - 每一关用 tint 换色（第一章青黑、第二章暖褐、第三章紫黑）；
## - 轻微摆动，避免像一张死贴图。

var tint := Color(0.012, 0.045, 0.055, 0.92)
var _t := 0.0
var _redraw_acc := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = get_viewport_rect().size
	get_viewport().size_changed.connect(func() -> void:
		size = get_viewport_rect().size
		queue_redraw())
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	_redraw_acc += delta
	if _redraw_acc >= 0.05:          # 20fps 重绘，摆动足够顺滑
		_redraw_acc = 0.0
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var k := h / 1080.0
	# 底部左右岩块
	_rock(Vector2(0, h), 1.0, k)
	_rock(Vector2(w, h), -1.0, k)
	# 顶部垂藤改用 AI 剪影（camera 子节点，见 LevelBase._build_vine_frame）


func _rock(corner: Vector2, dir: float, k: float) -> void:
	# 不规则轮廓 + 内层 + 顶缘微光，避免看起来像一块纯黑纸片
	var outer := PackedVector2Array([
		corner,
		corner + Vector2(0.0, -200.0 * k),
		corner + Vector2(dir * 45.0 * k, -250.0 * k),
		corner + Vector2(dir * 100.0 * k, -228.0 * k),
		corner + Vector2(dir * 150.0 * k, -285.0 * k),
		corner + Vector2(dir * 205.0 * k, -240.0 * k),
		corner + Vector2(dir * 250.0 * k, -160.0 * k),
		corner + Vector2(dir * 300.0 * k, 0.0),
	])
	draw_colored_polygon(outer, tint)
	var inner := PackedVector2Array([
		corner + Vector2(dir * 26.0 * k, 0.0),
		corner + Vector2(dir * 50.0 * k, -120.0 * k),
		corner + Vector2(dir * 118.0 * k, -175.0 * k),
		corner + Vector2(dir * 190.0 * k, -120.0 * k),
		corner + Vector2(dir * 228.0 * k, 0.0),
	])
	draw_colored_polygon(inner, Color(tint.r * 2.0, tint.g * 1.7, tint.b * 1.8, tint.a * 0.5))
	var rim := PackedVector2Array([
		corner + Vector2(0.0, -190.0 * k),
		corner + Vector2(dir * 45.0 * k, -240.0 * k),
		corner + Vector2(dir * 100.0 * k, -218.0 * k),
		corner + Vector2(dir * 150.0 * k, -275.0 * k),
		corner + Vector2(dir * 205.0 * k, -230.0 * k),
		corner + Vector2(dir * 250.0 * k, -150.0 * k),
	])
	draw_polyline(rim, Color(tint.r * 4.0, tint.g * 4.0, tint.b * 4.0, 0.22),
		2.5 * k, true)


func _vine(origin: Vector2, dir: float, k: float) -> void:
	# 两股更粗的水草/垂藤，不再画尖刺状叶片：避免读成"铁丝网"
	for s in 2:
		var base_x := origin.x + dir * (34.0 + s * 58.0) * k
		var length := (260.0 + s * 90.0) * k
		var pts := PackedVector2Array()
		for i in 9:
			var t := float(i) / 8.0
			var sway := sin(t * 2.4 + _t * 0.30 + s * 1.9) * 26.0 * k
			pts.append(Vector2(
				base_x + dir * (t * 52.0 * k + sway),
				origin.y + t * length))
		draw_polyline(pts, tint, (14.0 + s * 4.0) * k, true)
