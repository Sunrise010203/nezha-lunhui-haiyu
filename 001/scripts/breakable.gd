class_name Breakable
extends StaticBody3D
## 渊晶瓮 / 木桶：可被攻击击碎，掉落灵珠或回春莲
##
## 外观优先用现成 GLB（Poly Haven CC0）：第一/三章青瓷瓮，第二章龙宫深狱换成木桶。
## 碰撞体、血量、掉落逻辑一行没动 —— 命中判定仍是 r=0.38 / h=0.9 的圆柱，
## 所以"可击碎物"的玩法完全不变；文件缺失时自动回落原来的程序化陶瓮。

var drop_heal := false
## "urn"（青瓷瓮）/ "barrel"（木桶）
var style := "urn"
var _debris_kind := "stone"

const PROP_URN_BRONZE := "res://art/models/props/urn_bronze.glb"
const PROP_URN_PORCELAIN := "res://art/models/props/urn_porcelain.glb"
const PROP_BARREL := "res://art/models/props/barrel.glb"


func _ready() -> void:
	collision_layer = 4   # 与敌人同层，可被玩家攻击命中
	collision_mask = 0
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.38
	shape.height = 0.9
	col.shape = shape
	col.position.y = 0.45
	add_child(col)

	if _spawn_prop():
		return

	# ---------------------------------------------------------------- 兜底
	var ceramic := Game.std_mat(Color(0.12, 0.22, 0.28),
		Color(0.02, 0.06, 0.08), 0.4, 0.6)
	var glow := Game.std_mat(Color(0.4, 0.85, 0.85), Color(0.3, 0.8, 0.8),
		1.2, 0.4)
	var body := CylinderMesh.new()
	body.top_radius = 0.24
	body.bottom_radius = 0.36
	body.height = 0.62
	Game.add_mesh(self, body, ceramic, Vector3(0, 0.31, 0))
	var belly := SphereMesh.new()
	belly.radius = 0.34
	belly.height = 0.5
	Game.add_mesh(self, belly, ceramic, Vector3(0, 0.42, 0))
	var lip := TorusMesh.new()
	lip.inner_radius = 0.16
	lip.outer_radius = 0.24
	Game.add_mesh(self, lip, ceramic, Vector3(0, 0.66, 0))
	# 发光裂纹
	var crack := BoxMesh.new()
	crack.size = Vector3(0.04, 0.4, 0.04)
	Game.add_mesh(self, crack, glow, Vector3(0.3, 0.4, 0.12),
		Vector3(0, 0, 18))
	Game.add_mesh(self, crack, glow, Vector3(-0.26, 0.35, 0.18),
		Vector3(0, 30, -14))


func _spawn_prop() -> bool:
	## 成功挂上现成模型返回 true；任何一步失败都返回 false 让调用方走兜底。
	var path := PROP_BARREL
	var h := 0.88
	if style == "urn":
		path = PROP_URN_PORCELAIN if randf() < 0.5 else PROP_URN_BRONZE
		h = 0.78
	_debris_kind = "stone" if path == PROP_URN_PORCELAIN else "bronze"
	var model := Game.load_model(path, h, randf() * 360.0, 0.0, 45.0,
		true, false)
	if model == null:
		return false
	add_child(model)
	# 写实 PBR 在蓝雾场景里会发黑：补一点冷色自发光（只改材质，不影响玩法）
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s) as BaseMaterial3D
			if m:
				m.emission_enabled = true
				m.emission = Color(0.06, 0.13, 0.16)
				m.emission_energy_multiplier = 0.55
	return true


func take_damage(_dmg: float, _dir: float, _heavy := false) -> void:
	Game.play_sfx("hit", -6.0, 0.7)
	CombatVFX.debris(get_parent(), global_position + Vector3(0, 0.5, 0), _debris_kind, 4)
	CombatVFX.smoke(get_parent(), global_position, 0.9)
	if drop_heal:
		var p := Pickup.new()
		p.kind = Pickup.Kind.HEAL
		p.position = global_position + Vector3(0, 0.8, 0)
		get_parent().add_child(p)
	else:
		for i in randi_range(2, 3):
			var p := Pickup.new()
			p.kind = Pickup.Kind.ENERGY
			p.position = global_position + Vector3(randf_range(-0.4, 0.4),
				0.7 + randf_range(0.0, 0.4), 0)
			get_parent().add_child(p)
	queue_free()
