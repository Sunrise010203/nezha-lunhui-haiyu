# -*- coding: utf-8 -*-
"""把新的模块化环境段追加进 level_1.gd（不改动原有编排逻辑）。"""
import io

P = r"E:\godot_game_by_fable\001\scripts\level_1.gd"

BLOCK = r'''

# ================================================================ 新环境：模块化结构资产
## 走道 / 栏杆 / 柱 / 灯笼 / 碎石 换成 T16–T24 的 Tripo 结构件。
## 碰撞仍由 LevelBase 的 _platform 提供，这里只替换可见表面。

const ENV_DIR := "res://art/models/glb_game/"
const _ENV_LO := {
	"T16_lantern": "T16_lantern_lo.glb",
	"T17_pillar": "T17_pillar_lo.glb",
	"T18_shaft": "T18_shaft_lo.glb",
	"T19_balustrade": "T19_balustrade_lo.glb",
	"T20_post": "T20_post_lo.glb",
	"T23_rubble": "T23_rubble_lo.glb",
	"T24_barnacle": "T24_barnacle_lo.glb",
}

var _env_cache: Dictionary = {}
var _m_walk: StandardMaterial3D
var _m_wall: StandardMaterial3D
var _m_deep: StandardMaterial3D
var _m_bronze: StandardMaterial3D


func _init_env_mats() -> void:
	if _m_walk != null:
		return
	_m_walk = Game.std_mat(Color(0.205, 0.335, 0.365), Color(0.015, 0.05, 0.06), 0.06, 0.85)
	_m_wall = Game.std_mat(Color(0.145, 0.245, 0.275), Color(0.01, 0.03, 0.04), 0.08, 0.8)
	_m_deep = Game.std_mat(Color(0.085, 0.145, 0.165), Color(0.005, 0.02, 0.025), 0.1, 0.75)
	_m_bronze = Game.std_mat(Color(0.34, 0.26, 0.13), Color(0.0, 0.0, 0.0), 0.3, 0.9)


func _env_scene(key: String) -> PackedScene:
	if _env_cache.has(key):
		return _env_cache[key]
	var file: String = _ENV_LO.get(key, key + ".glb")
	var ps := load(ENV_DIR + file) as PackedScene
	_env_cache[key] = ps
	return ps


func _env_aabb(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var box := m.global_transform * m.get_aabb()
		if first:
			out = box
			first = false
		else:
			out = out.merge(box)
	return out


func _env_tint(root: Node3D, mul: float) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or m.mesh.get_surface_count() == 0:
			continue
		var src := m.get_active_material(0)
		if src is BaseMaterial3D:
			var nm := (src as BaseMaterial3D).duplicate() as BaseMaterial3D
			var c := nm.albedo_color
			nm.albedo_color = Color(c.r * mul, c.g * mul, c.b * mul, c.a)
			m.material_override = nm


func _env_place(key: String, pos: Vector3, h: float, yaw: float = 0.0,
		tint: float = 0.62) -> Node3D:
	## 以 pos 为"底面中心"放置，按目标高度等比缩放。
	var ps := _env_scene(key)
	if ps == null:
		return null
	var n := ps.instantiate() as Node3D
	add_child(n)
	var ab := _env_aabb(n)
	if ab.size.y > 0.0001:
		var s := h / ab.size.y
		n.scale = Vector3(s, s, s)
	n.rotation.y = deg_to_rad(yaw)
	var ab2 := _env_aabb(n)
	n.position += Vector3(
		pos.x - (ab2.position.x + ab2.size.x * 0.5),
		pos.y - ab2.position.y,
		pos.z - (ab2.position.z + ab2.size.z * 0.5))
	_env_tint(n, tint)
	return n


func _dress_walkway(body: StaticBody3D, x0: float, x1: float, ytop: float,
		deep: float) -> void:
	_init_env_mats()
	var w := x1 - x0
	if w < 1.0:
		return
	# 1) 隐藏 LevelBase 原来的大石块（保留碰撞、焦散、符文砖）
	for c in body.get_children():
		if c is MeshInstance3D and c.mesh is BoxMesh:
			if (c.mesh as BoxMesh).size.x > w * 0.8:
				c.visible = false
	# 2) 新走道面 + 立面
	var slab := BoxMesh.new()
	slab.size = Vector3(w, 0.34, 5.0)
	Game.add_mesh(body, slab, _m_walk, Vector3(0, deep * 0.5 - 0.17, 0))
	var lip := BoxMesh.new()
	lip.size = Vector3(w, 0.17, 0.38)
	Game.add_mesh(body, lip, _m_wall, Vector3(0, deep * 0.5 - 0.085, 2.56))
	var band := BoxMesh.new()
	band.size = Vector3(w, 0.055, 0.06)
	Game.add_mesh(body, band, _m_bronze, Vector3(0, deep * 0.5 - 0.30, 2.62))
	var face := BoxMesh.new()
	face.size = Vector3(w, 0.78, 0.20)
	Game.add_mesh(body, face, _m_wall, Vector3(0, deep * 0.5 - 0.56, 2.52))
	var foot := BoxMesh.new()
	foot.size = Vector3(w, 0.22, 0.34)
	Game.add_mesh(body, foot, _m_deep, Vector3(0, deep * 0.5 - 1.02, 2.56))

	# 3) 后沿栏杆（隔段铺，避免整条连续挡住背景）
	if w >= 7.0:
		var seg := 5.2
		var cnt := int(w / seg)
		for i in cnt:
			var bx := x0 + (float(i) + 0.5) * (w / float(maxi(cnt, 1)))
			_env_place("T19_balustrade", Vector3(bx, ytop, -2.12), 1.02,
				0.0, 0.52)
	# 4) 柱列：柱础 + 柱身 + 柱头（断柱高低错落）
	if w >= 9.0:
		var step := 11.0
		var n := int(w / step)
		for i in n:
			var px := x0 + 3.0 + float(i) * step
			if px > x1 - 1.5:
				continue
			var hgt := 2.1 + float((i * 7 + int(x0)) % 5) * 0.42
			var zc := -2.55
			_env_place("T17_pillar", Vector3(px, ytop - 0.06, zc), 0.92, 0.0, 0.50)
			var shaft := _env_place("T18_shaft", Vector3(px, ytop - 0.02, zc), hgt, 0.0, 0.50)
			if shaft != null and hgt > 2.6:
				_env_place("T18_shaft", Vector3(px, ytop - 0.02 + hgt * 0.32, zc),
					hgt * 0.66, 0.0, 0.50)
	# 5) 灯笼（画面边缘节奏点，带暖光）
	if w >= 12.0:
		var lx := x0 + 1.6
		while lx < x1 - 1.6:
			_env_place("T16_lantern", Vector3(lx, ytop, 1.86), 1.32, 0.0, 0.58)
			var lamp := OmniLight3D.new()
			lamp.light_color = Color(1.0, 0.66, 0.34)
			lamp.light_energy = 1.15
			lamp.omni_range = 5.4
			lamp.position = Vector3(lx, ytop + 0.72, 1.80)
			add_child(lamp)
			lx += 24.0
	# 6) 前沿碎石 / 藤壶：只贴立面下沿，不占玩法面
	var rng := RandomNumberGenerator.new()
	rng.seed = int(x0 * 13.0) + int(x1)
	for i in maxi(int(w / 7.0), 1):
		var rx := rng.randf_range(x0 + 0.6, x1 - 0.6)
		_env_place("T23_rubble", Vector3(rx, ytop - 0.86, 2.66),
			rng.randf_range(0.26, 0.44), rng.randf_range(0, 360), 0.46)
		var bx := rng.randf_range(x0 + 0.6, x1 - 0.6)
		_env_place("T24_barnacle", Vector3(bx, ytop - 0.34, 2.60),
			rng.randf_range(0.16, 0.26), rng.randf_range(0, 360), 0.50)


func _platform(x0: float, x1: float, ytop: float, deep := 1.6,
		dark := false) -> StaticBody3D:
	var body := super._platform(x0, x1, ytop, deep, dark)
	_dress_walkway(body, x0, x1, ytop, deep)
	return body
'''

src = open(P, "rb").read().decode("utf-8")
if "新环境：模块化结构资产" in src:
    print("already patched")
else:
    open(P, "wb").write((src + BLOCK).encode("utf-8"))
    print("appended", len(BLOCK), "chars")
