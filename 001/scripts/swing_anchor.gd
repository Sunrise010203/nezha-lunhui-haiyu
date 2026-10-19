class_name SwingAnchor
extends Node3D
## 龙宫铜环：混天绫摆荡锚点
## 加入 group "swing_anchor"，玩家按下 F 时在附近搜索它。
## 注意：本脚本刻意不引用 Game 单例（全局类在引擎启动早期编译时可能还解析不到 autoload），
## 需要单例能力的地方走 /root/Game 运行时查找。

var radius := 0.55
var _base_y := 0.0
var _t := 0.0
var _pulse_t := 0.0
var _ring: MeshInstance3D
var _glow: MeshInstance3D


func _ready() -> void:
	add_to_group("swing_anchor")
	_base_y = position.y
	_t = randf() * TAU
	var torus := TorusMesh.new()
	torus.inner_radius = radius * 0.80
	torus.outer_radius = radius
	var ring_mat := _mat(Color(0.86, 0.68, 0.30), Color(0.72, 0.46, 0.10),
		0.8, 0.35, 0.85)
	_ring = _mesh(self, torus, ring_mat, Vector3.ZERO)
	# 内圈青色灵光（不额外加灯，靠自发光 + glow）
	var inner := TorusMesh.new()
	inner.inner_radius = radius * 0.42
	inner.outer_radius = radius * 0.52
	var gmat := _mat(Color(0.42, 0.9, 0.95, 0.6), Color(0.38, 0.95, 1.0),
		1.1, 0.3)
	gmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_glow = _mesh(self, inner, gmat, Vector3(0, 0, 0.03))
	# 三根短链，暗示"悬在龙宫穹顶"
	var chain := CylinderMesh.new()
	chain.top_radius = 0.025
	chain.bottom_radius = 0.025
	chain.height = 0.9
	var chain_mat := _mat(Color(0.35, 0.28, 0.16), Color(0.2, 0.14, 0.06),
		0.4, 0.6, 0.7)
	for i in 3:
		_mesh(self, chain, chain_mat,
			Vector3(-0.18 + i * 0.18, radius + 0.45, 0))


func _mat(albedo: Color, emission: Color, e_energy: float, rough: float,
		metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.roughness = rough
	m.metallic = metal
	if emission != Color.BLACK:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = e_energy
	return m


func _mesh(parent: Node, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _game() -> Node:
	return get_node_or_null("/root/Game")


func _process(delta: float) -> void:
	_t += delta
	_pulse_t = maxf(_pulse_t - delta, 0.0)
	rotation.y += delta * 0.9
	position.y = _base_y + sin(_t * 1.6) * 0.07
	var s := 1.0 + _pulse_t * 1.2
	scale = Vector3.ONE * s
	if _glow:
		_glow.rotation.y -= delta * 2.0


func pulse() -> void:
	## 被混天绫抓住时闪一下
	_pulse_t = 0.35
	var g := _game()
	if g:
		g.call("play_sfx", "orb", -9.0, 1.3)
		g.call("burst", get_parent(), global_position,
			Color(1.0, 0.8, 0.35), 10, 3.0, 0.05, 0.35)
