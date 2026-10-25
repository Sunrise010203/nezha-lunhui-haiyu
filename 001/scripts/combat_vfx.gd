@static_unload
class_name CombatVFX
extends RefCounted
## Shared assets; visual events only. No collisions, lights, damage or resource changes.
const FX := preload("res://scripts/vfx_instance.gd")
static var _glow: Shader
static var _smoke: Shader
const FIRE := Color(1.0, 0.88, 0.68)
const JADE := Color(0.30, 0.86, 0.76)
const MAX_TRANSIENT := 96
static var _meshes: Dictionary = {}
static var _textures: Dictionary = {}
static var _quad: QuadMesh
static var _rng: RandomNumberGenerator

static func release_cache() -> void:
	_meshes.clear()
	_textures.clear()
	_quad = null
	_rng = null
	_glow = null
	_smoke = null

static func _random() -> RandomNumberGenerator:
	if _rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.randomize() # Separate stream: cosmetic debris must not change loot RNG.
	return _rng

static func texture(id: String) -> Texture2D:
	if not _textures.has(id):
		_textures[id] = load("res://art/vfx/textures/%s_rgba.png" % id)
	return _textures[id] as Texture2D

static func mesh(id: String) -> Mesh:
	if id == "quad":
		if _quad == null:
			_quad = QuadMesh.new()
			_quad.size = Vector2.ONE
		return _quad
	if not _meshes.has(id):
		var scene := load("res://art/vfx/templates/fx_%s.glb" % id) as PackedScene
		if scene == null:
			return null
		var root := scene.instantiate()
		var nodes := root.find_children("*", "MeshInstance3D", true, false)
		if root is MeshInstance3D:
			nodes.push_front(root)
		if not nodes.is_empty():
			_meshes[id] = (nodes[0] as MeshInstance3D).mesh
		root.free()
	return _meshes.get(id) as Mesh

static func material(tex: String, color := Color.WHITE, strip := false, smoke := false) -> ShaderMaterial:
	if _glow == null:
		_glow = load("res://shaders/combat_vfx.gdshader")
	if _smoke == null:
		_smoke = load("res://shaders/combat_smoke.gdshader")
	var mat := ShaderMaterial.new()
	mat.shader = _smoke if smoke else _glow
	mat.set_shader_parameter("effect_tex", texture(tex))
	mat.set_shader_parameter("tint", color)
	if not smoke:
		mat.set_shader_parameter("strip", strip)
		mat.set_shader_parameter("scroll", -1.1 if strip else 0.0)
	return mat

static func _spawn(parent: Node, pos: Vector3, id: String, mat: Material,
		duration: float, begin: Vector3, end: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return null
	if parent.get_tree().get_node_count_in_group("combat_vfx_transient") >= MAX_TRANSIENT:
		return null
	var fx := FX.new()
	fx.mesh = mesh(id)
	if fx.mesh == null:
		fx.free()
		return null
	fx.name = "VFX_" + id
	fx.material_override = mat
	fx.lifetime = duration
	fx.start_scale = begin
	fx.end_scale = end
	fx.rotation_degrees = rot
	parent.add_child(fx)
	fx.global_position = pos
	return fx

static func sprite(parent: Node, pos: Vector3, tex: String, color: Color,
		size: float, duration: float, angle := 0.0, smoke := false) -> MeshInstance3D:
	return _spawn(parent, pos, "quad", material(tex, color, false, smoke), duration,
		Vector3.ONE * size * 0.65, Vector3.ONE * size, Vector3(0, 0, angle))

static func slash(parent: Node, pos: Vector3, facing: float, heavy := false, combo := 1) -> void:
	var rot := Vector3(90, 0, -25 if combo == 2 else 25)
	if facing < 0:
		rot.z += 180
	var size := 1.05 if heavy else 0.83
	var fx := _spawn(parent, pos + Vector3(0, 0.95, 0.32), "arc_wide" if heavy else "arc_narrow",
		material("flame_flow", FIRE, true), 0.30 if heavy else 0.20,
		Vector3.ONE * size * 0.80, Vector3.ONE * size, rot)
	if fx:
		fx.set("spin", Vector3(0, 0, -facing * 2.8))

static func impact(parent: Node, pos: Vector3, color := FIRE, heavy := false) -> void:
	sprite(parent, pos + Vector3(0, 0, 0.35), "impact_flash", color,
		1.25 if heavy else 0.72, 0.22 if heavy else 0.14, _random().randf_range(-35,35))

static func smoke(parent: Node, pos: Vector3, size := 1.5) -> void:
	var fx := sprite(parent, pos + Vector3(0, 0.2, -0.18), "smoke", Color(0.34,0.39,0.42,0.35), size, 0.72, 0, true)
	if fx:
		fx.set("drift", Vector3(0,0.55,0))

static func ground_wave(parent: Node, pos: Vector3, radius: float, color := FIRE) -> void:
	_spawn(parent, pos + Vector3(0,0.08,0), "ring_wave", material("flame_flow",color,true),
		0.46, Vector3(0.25,0.3,0.25), Vector3(radius/1.2,0.4,radius/1.2))

static func debris(parent: Node, pos: Vector3, kind := "stone", count := 4) -> void:
	for i in mini(count,6):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.64,0.60,0.47) if kind == "bone" else (Color(0.5,0.3,0.1) if kind == "bronze" else Color(0.3,0.39,0.42))
		mat.roughness = 0.8
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var size := _random().randf_range(0.14,0.30)
		var fx := _spawn(parent,pos,"shard_"+kind,mat,0.60,Vector3.ONE*size,Vector3.ONE*size*0.7)
		if fx:
			fx.set("drift",Vector3(_random().randf_range(-2.2,2.2),_random().randf_range(1.5,3.2),_random().randf_range(-0.45,0.45)))
			fx.set("gravity",9.0)
			fx.set("spin",Vector3(4,6,3))

static func slam(parent: Node, pos: Vector3, boosted := false) -> void:
	ground_wave(parent,pos,2.9 if boosted else 2.3)
	impact(parent,pos+Vector3(0,0.35,0),FIRE,true)
	smoke(parent,pos,2.6 if boosted else 1.8)
	debris(parent,pos+Vector3(0,0.1,0),"stone",4)

static func nova(parent: Node, pos: Vector3) -> void:
	ground_wave(parent,pos,4.6)
	_spawn(parent,pos,"dome",material("flame_flow",Color(1,0.8,0.5,0.30),true),
		0.42,Vector3.ONE*0.3,Vector3(4.3,2.2,2.1))
	for side in [-1.0,1.0]:
		var mat := material("flame_flow",Color(1,0.88,0.65,0.7),true)
		mat.set_shader_parameter("axial",true)
		_spawn(parent,pos+Vector3(0,0.45,0),"cone_wide",mat,0.35,
			Vector3.ONE*0.15,Vector3(0.75,1.7,0.75),Vector3(0,0,-90*side))
		var fx := sprite(parent,pos+Vector3(side*1.15,1.15,0.1),"flame_tongue",Color.WHITE,2.1,0.48,-side*25)
		if fx:
			fx.set("drift",Vector3(side*1.4,0.45,0))
	smoke(parent,pos+Vector3(0,0.5,0),3.3)

static func flame_wisp(parent: Node, pos: Vector3, size := 0.8) -> void:
	var fx := sprite(parent,pos,"flame_tongue",Color(1,0.9,0.7,0.5),size,0.28)
	if fx:
		fx.set("drift",Vector3(0,-0.4,0))

static func ring_trail(parent: Node, pos: Vector3, direction: float) -> void:
	var fx := sprite(parent,pos,"flame_flow",Color(1,0.8,0.3,0.38),1.0,0.18)
	if fx:
		fx.set("start_scale",Vector3(1.15,0.35,1))
		fx.set("end_scale",Vector3(1.5,0.2,1))
		fx.set("drift",Vector3(-direction*0.8,0,0))

static func splash(parent: Node, pos: Vector3, direction := 1.0, perfect := false) -> void:
	var fx := sprite(parent,pos+Vector3(0,0,0.3),"water_splash",JADE,1.7 if perfect else 1.15,0.35,-90*direction)
	if fx:
		fx.set("drift",Vector3(direction*1.0,0.15,0))
	if perfect:
		impact(parent,pos,Color(1,0.92,0.65),true)

static func volley(parent: Node, pos: Vector3, direction: float) -> void:
	var mat := material("flame_flow",Color(0.25,0.8,0.72,0.35),true)
	# Use a white mask on water; never tint the orange flame RGB cyan.
	mat.set_shader_parameter("effect_tex", texture("water_splash"))
	mat.set_shader_parameter("axial",true)
	_spawn(parent,pos,"cone_narrow",mat,0.32,Vector3.ONE*0.15,Vector3(1.2,1.1,1.2),Vector3(0,0,-90*direction))
	splash(parent,pos+Vector3(direction*0.6,0,0),direction)

static func guard(parent: Node3D) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for id in ["dome","quad"]:
		var mi := MeshInstance3D.new()
		mi.name = "VFX_Guard_" + id
		mi.mesh = mesh(id)
		mi.material_override = material("water_splash" if id == "dome" else "rune_mask",Color(0.25,0.85,0.75,0.28 if id == "dome" else 0.65))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		mi.visible = false
		parent.add_child(mi)
		result.append(mi)
	return result

static func warm(parent: Node) -> void:
	for id in ["arc_narrow","arc_wide","ring_flat","ring_wave","cone_narrow","cone_wide","dome","shard_stone","shard_bone","shard_bronze"]:
		mesh(id)
	for id in ["flame_tongue","flame_flow","water_splash","impact_flash","smoke","rune_mask"]:
		texture(id)
	# Same materials as runtime; only short-lived instances outside the play area.
	slash(parent,Vector3(0,-300,0),1.0)
	smoke(parent,Vector3(0,-300,0))
	splash(parent,Vector3(0,-300,0))
	debris(parent,Vector3(0,-300,0),"stone",1)
