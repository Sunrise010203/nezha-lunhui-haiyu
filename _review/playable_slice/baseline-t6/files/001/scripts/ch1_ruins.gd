extends Node3D
## Chapter-local visuals only. Existing LevelBase bodies own all gameplay physics.

const MODEL_DIR := "res://art/models/ch1_ruins/"
var near: Node3D
var mid: Node3D
var far: Node3D
var _scenes: Dictionary = {}
var _materials: Dictionary = {}
var _stone: StandardMaterial3D
var _wall: StandardMaterial3D
var _bronze: StandardMaterial3D
var _stone_normal: NoiseTexture2D


func _ready() -> void:
	near = Node3D.new()
	near.name = "NearRuins"
	add_child(near)
	mid = Node3D.new()
	mid.name = "MidRuins"
	add_child(mid)
	far = Node3D.new()
	far.name = "FarPalace"
	add_child(far)
	_stone = _stone_material(Color(0.60, 0.67, 0.65), 0.48)
	_wall = _stone_material(Color(0.31, 0.41, 0.42), 0.65)
	_bronze = Game.std_mat(Color(0.26, 0.24, 0.14), Color.BLACK, 0.35, 0.73)


func _stone_material(color: Color, tiling: float) -> StandardMaterial3D:
	if _stone_normal == null:
		var noise := FastNoiseLite.new()
		noise.seed = 41
		noise.frequency = 0.055
		_stone_normal = NoiseTexture2D.new()
		_stone_normal.noise = noise
		_stone_normal.seamless = true
		_stone_normal.as_normal_map = true
		_stone_normal.bump_strength = 1.8
		_stone_normal.width = 256
		_stone_normal.height = 256
	var m := StandardMaterial3D.new()
	m.albedo_texture = Game.tex("res://art/stone.png")
	m.albedo_color = color
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * tiling
	m.roughness = 0.86
	m.normal_enabled = true
	m.normal_texture = _stone_normal
	m.normal_scale = 0.6
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3,
		material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return Game.add_mesh(parent, mesh, material, pos)


func model_aabb(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		var box := mi.global_transform * mi.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out


func _model(key: String, pos: Vector3, height: float, parent: Node3D,
		yaw := 0.0, tint := 0.72, width := 0.0) -> Node3D:
	if not _scenes.has(key):
		_scenes[key] = load(MODEL_DIR + key + ".glb")
	var scene: PackedScene = _scenes[key]
	var root := scene.instantiate() as Node3D
	root.name = key
	parent.add_child(root)
	var box := model_aabb(root)
	var scale_y := height / maxf(box.size.y, 0.001)
	var scale_xz := width / maxf(box.size.x, 0.001) if width > 0.0 else scale_y
	root.scale = Vector3(scale_xz, scale_y, scale_xz)
	root.rotation.y = deg_to_rad(yaw)
	box = model_aabb(root)
	root.global_position += pos - Vector3(box.get_center().x, box.position.y, box.get_center().z)
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var src := mi.get_active_material(0) as BaseMaterial3D
		if src == null:
			continue
		var cache_key := "%s:%.2f" % [src.get_instance_id(), tint]
		if not _materials.has(cache_key):
			var m := src.duplicate() as BaseMaterial3D
			m.albedo_color *= Color(tint * 0.88, tint, tint * 1.02)
			m.metallic = minf(m.metallic, 0.2)
			m.roughness = maxf(m.roughness, 0.7)
			m.emission_enabled = false
			_materials[cache_key] = m
		mi.material_override = _materials[cache_key]
		mi.visibility_range_end = 100.0
	return root


func dress_platform(body: StaticBody3D, x0: float, x1: float, top: float,
		depth: float, floating := false) -> void:
	var width := x1 - x0
	# Hide only the old visual meshes. Keep every shape and its dimensions intact.
	for child in body.get_children():
		if child is MeshInstance3D:
			child.visible = false
	var zdepth := 4.2 if floating else 5.0
	var surface := depth * 0.5
	_box(body, Vector3(width, minf(depth, 0.8), zdepth),
		Vector3(0, surface - minf(depth, 0.8) * 0.5, 0), _wall)
	# Slightly irregular individual slabs expose real joints under raking light.
	var count := maxi(1, int(ceil(width / 1.5)))
	var slab_width := width / count
	var slab := BoxMesh.new()
	slab.size = Vector3(slab_width - 0.025, 0.13, zdepth / 3.0 - 0.025)
	var tiles := MultiMesh.new()
	tiles.transform_format = MultiMesh.TRANSFORM_3D
	tiles.mesh = slab
	tiles.instance_count = count * 3
	for row in 3:
		for i in count:
			tiles.set_instance_transform(row * count + i, Transform3D(Basis.IDENTITY,
				Vector3(-width * 0.5 + slab_width * (i + 0.5), surface - 0.065,
				-zdepth * 0.5 + zdepth / 3.0 * (row + 0.5))))
	var paving := MultiMeshInstance3D.new()
	paving.multimesh = tiles
	paving.material_override = _stone
	paving.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(paving)
	_box(body, Vector3(width, 0.18, 0.20), Vector3(0, surface - 0.16, zdepth * 0.5), _stone)
	_box(body, Vector3(width, 0.07, 0.06), Vector3(0, surface - 0.35, zdepth * 0.5 + 0.03), _bronze)
	if floating:
		for side in [-1.0, 1.0]:
			_model("rubble", Vector3((x0 + x1) * 0.5 + side * width * 0.22,
				top - 0.92, 1.35), 0.54, body, side * 35.0, 0.68, width * 0.52)
		return
	for i in maxi(1, int(width / 2.5)):
		var bx := -width * 0.5 + (i + 0.5) * width / maxi(1, int(width / 2.5))
		_box(body, Vector3(width / maxi(1, int(width / 2.5)) - 0.04, 0.5, 0.22),
			Vector3(bx, surface - 0.64, 2.48), _wall)
	# The lower catch-floor of the bridge pool must remain submerged and undecorated.
	if x0 > 100.0 and top < 5.0:
		return
	if width >= 7.0:
		for x in [x0 + 1.7, x1 - 1.7]:
			var rail := _model("railing", Vector3(x, top, -2.24), 0.85, near, 90.0)
			rail.add_to_group("ch1_ruin_rail")
			_model("post", Vector3(x - 0.76, top, -2.24), 0.98, near)
	if width >= 10.0:
		_lantern(Vector3(x0 + 1.25, top, -1.82))
		_model("steps", Vector3(x1 - 0.75, top - 0.65, -3.2), 0.65, near, 90.0)
	# Debris clusters on bridge piers, not on the player's route.
	for x in [x0 + 0.5, x1 - 0.45]:
		_model("rubble", Vector3(x, top - 0.65, 2.53), 0.34, near, x * 13.0)
		_model("barnacle", Vector3(x + 0.14, top - 0.26, 2.54), 0.20, near, 40.0)


func _lantern(pos: Vector3) -> void:
	_model("lantern", pos, 1.3, near, 20.0, 0.9)
	var light := OmniLight3D.new()
	light.position = pos + Vector3(0, 0.85, 0)
	light.light_color = Color(1.0, 0.66, 0.30)
	light.light_energy = 1.4
	light.omni_range = 3.6
	light.light_volumetric_fog_energy = 0.0
	light.distance_fade_enabled = true
	light.distance_fade_begin = 24.0
	light.distance_fade_length = 6.0
	light.set_meta("light_tuned", true)
	near.add_child(light)
	var core := SphereMesh.new()
	core.radius = 0.075
	core.height = 0.15
	core.radial_segments = 8
	core.rings = 4
	var glow := Game.std_mat(Color(1.0, 0.65, 0.22), Color(1.0, 0.46, 0.10), 0.0, 0.6)
	glow.emission_energy_multiplier = 2.0
	Game.add_mesh(near, core, glow, pos + Vector3(0, 0.87, 0))


func _column(pos: Vector3, height: float, diameter: float, complete: bool) -> void:
	var root := Node3D.new()
	root.name = "RuinColumn"
	mid.add_child(root)
	root.add_to_group("ch1_ruin_column")
	_model("pillar_base", pos, diameter * 1.1, root, 0.0, 0.78, diameter * 1.45)
	var base_height := diameter * 0.7
	var cap_height := diameter * 1.4 if complete else 0.0
	var shaft_height := height - base_height - cap_height
	# Stack almost-natural-proportion segments, preserving texture density and diameter.
	var segments := maxi(1, int(ceil(shaft_height / (diameter * 2.4))))
	var segment_height := shaft_height / segments
	for i in segments:
		_model("pillar_shaft", pos + Vector3(0, base_height + i * segment_height, 0),
			segment_height + 0.035, root, 90.0 * (i % 4), 0.76, diameter)
	if complete:
		_model("capital", pos + Vector3(0, height - cap_height - 0.12, 0),
			cap_height, root, 12.0, 0.80, diameter * 1.6)
	_model("rubble", pos + Vector3(diameter * 0.5, 0, 0.3), diameter * 0.55, root, 26.0)


func build_depth() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(520, 160)
	var matte := ShaderMaterial.new()
	matte.shader = preload("res://shaders/ch1_far_matte.gdshader")
	matte.set_shader_parameter("palace", Game.tex("res://art/ref/ch1_palace_far.png"))
	var backdrop := Game.add_mesh(far, quad, matte, Vector3(80, 18, -90))
	backdrop.name = "DistantPalaceMatte"
	backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Continuous architecture across the chapter, with two genuinely distinct depths.
	for i in 18:
		var x := -22.0 + i * 12.0
		var ground := 1.0 if x > 58.0 and x < 124.0 else -3.0
		var height := 10.0 + float((i * 7) % 4) * 1.3
		var z := -7.0 - float(i % 3) * 1.4
		_column(Vector3(x, ground, z), height, 1.10 + float(i % 2) * 0.18, i % 3 != 1)
		if i % 2 == 0:
			_model("coral", Vector3(x - 0.9, ground + 0.4, z + 0.8), 2.5, mid, i * 37.0, 0.56)
	for i in 15:
		var x := -35.0 + i * 16.0
		var ground := -1.0 if x > 58.0 and x < 124.0 else -5.0
		_column(Vector3(x, ground, -22.0), 15.0 + float(i % 3), 1.4, true)
		if i % 2 == 0:
			var arch := _model("arch", Vector3(x + 8.0, ground, -23.0), 11.0, mid, 90.0, 0.64)
			arch.name = "RearArch"
			_box(mid, Vector3(16, 0.65, 3.0), Vector3(x + 8.0, ground - 0.32, -22.0), _wall)
			for offset in [2.0, 14.0]:
				_box(mid, Vector3(4.0, 0.55, 1.8), Vector3(x + offset, ground + 13.0, -23.0), _wall)
	# Local water behind the play strip catches light without covering walk surfaces.
	var water := PlaneMesh.new()
	water.size = Vector2(300, 40)
	water.subdivide_width = 32
	water.subdivide_depth = 8
	var water_mat := ShaderMaterial.new()
	water_mat.shader = preload("res://shaders/ch1_water.gdshader")
	var pool := Game.add_mesh(mid, water, water_mat, Vector3(80, -2.3, -25))
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 8:
		var beam := SpotLight3D.new()
		beam.position = Vector3(-5 + i * 26, 20, -9)
		beam.rotation_degrees = Vector3(-76, -18, 0)
		beam.light_color = Color(0.48, 0.83, 0.88)
		beam.light_energy = 5.0
		beam.spot_range = 36.0
		beam.spot_angle = 16.0
		beam.light_volumetric_fog_energy = 0.6
		beam.distance_fade_enabled = true
		beam.distance_fade_begin = 42.0
		beam.distance_fade_length = 12.0
		beam.set_meta("light_tuned", true)
		mid.add_child(beam)


func tune_environment(level: Node3D) -> void:
	var env: Environment = level.get("_env")
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.016, 0.055, 0.070)
	env.ambient_light_color = Color(0.38, 0.62, 0.67)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = 0.009
	env.fog_light_color = Color(0.055, 0.15, 0.18)
	env.fog_light_energy = 0.5
	env.fog_height_density = 0.0
	env.fog_aerial_perspective = 0.20
	env.volumetric_fog_density = 0.004
	env.volumetric_fog_length = 95.0
	env.volumetric_fog_emission = Color(0.006, 0.022, 0.028)
	env.ssao_enabled = true
	env.ssao_intensity = 1.1
	env.ssao_radius = 0.7
	env.ssr_enabled = true
	env.ssr_max_steps = 48
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 0.93
	var sun: DirectionalLight3D = level.get("_sun")
	sun.rotation_degrees = Vector3(-62, -24, 0)
	sun.light_color = Color(0.68, 0.88, 0.94)
	sun.light_energy = 1.6
	sun.directional_shadow_max_distance = 55.0
