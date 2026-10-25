extends Node3D
# 逐个载入 GLB，自动取景打光，截图到 out/ 。用于确认 15 个 GLB 分别是什么资产。

const SRC_DIR := "E:/godot_game_by_fable/game_assets/glb_new"
const OUT_DIR := "E:/godot_game_by_fable/game_assets/_previews_new"
const SHOT_SIZE := Vector2i(900, 900)

var cam: Camera3D
var l1: DirectionalLight3D
var l2: DirectionalLight3D
var l3: DirectionalLight3D


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.086, 0.094, 0.11)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.62, 0.70)
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 1.05
	e.glow_enabled = true
	e.glow_intensity = 0.35
	e.glow_bloom = 0.05
	env.environment = e
	add_child(env)

	cam = Camera3D.new()
	cam.fov = 32.0
	add_child(cam)

	l1 = _mk_light(Vector3(-0.55, -1.0, -0.45), 3.4, Color(1.0, 0.96, 0.90))
	l2 = _mk_light(Vector3(0.85, -0.35, -0.75), 1.5, Color(0.62, 0.80, 1.0))
	l3 = _mk_light(Vector3(0.10, -0.25, 1.0), 1.1, Color(0.75, 0.90, 1.0))

	var files := DirAccess.get_files_at(SRC_DIR)
	var names: Array[String] = []
	for f in files:
		if f.to_lower().ends_with(".glb"):
			names.append(f)
	names.sort()

	for f in names:
		await _shoot(SRC_DIR + "/" + f, f.get_basename())

	get_tree().quit()


func _mk_light(dir: Vector3, energy: float, col: Color) -> DirectionalLight3D:
	var l := DirectionalLight3D.new()
	l.light_energy = energy
	l.light_color = col
	l.shadow_enabled = true
	add_child(l)
	l.basis = Basis.looking_at(dir.normalized(), Vector3.UP)
	return l


func _shoot(path: String, out_name: String) -> void:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(path, state)
	if err != OK:
		print("LOAD FAIL ", path, " ", err)
		return
	var root := doc.generate_scene(state)
	add_child(root)
	await get_tree().process_frame

	var aabb := AABB()
	var first := true
	for mi in _meshes(root):
		var box: AABB = mi.global_transform * mi.get_aabb()
		aabb = box if first else aabb.merge(box)
		first = false
	if first:
		print("NO MESH ", path)
		root.queue_free()
		return

	var c := aabb.get_center()
	var r: float = maxf(aabb.size.length() * 0.5, 0.001)
	var dist := r / tan(deg_to_rad(cam.fov * 0.5)) * 1.22
	var dir := Vector3(0.62, 0.28, 0.74).normalized()
	cam.look_at_from_position(c + dir * dist, c, Vector3.UP)
	cam.near = maxf(dist * 0.02, 0.01)
	cam.far = dist * 6.0

	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.resize(SHOT_SIZE.x, SHOT_SIZE.y, Image.INTERPOLATE_LANCZOS)
	img.save_png(OUT_DIR + "/" + out_name + ".png")
	print("SHOT ", out_name)
	root.queue_free()
	await get_tree().process_frame


func _meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if n is MeshInstance3D:
		out.append(n as MeshInstance3D)
	for ch in n.get_children():
		out.append_array(_meshes(ch))
	return out
