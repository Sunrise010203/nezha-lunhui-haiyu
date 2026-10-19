extends SceneTree
## 模型体检：直接 load 一个 glb，打印节点层级、每个 MeshInstance3D 的
## AABB / 面数 / 材质槽 / skeleton，用来核对 Blender 里的判断。
## 用法：
##   <Godot> --headless --path 001 --script res://tools/probe_model.gd -- res://art/models/nezha.glb


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var path := "res://art/models/nezha.glb"
	if args.size() > 0:
		path = args[0]
	print("[probe] path=", path)
	var ps := load(path) as PackedScene
	if ps == null:
		print("[probe] FAILED to load")
		quit(1)
		return
	var root_node := ps.instantiate()
	get_root().add_child(root_node)
	_dump(root_node, 0)
	quit(0)


func _dump(n: Node, depth: int) -> void:
	var pad := "  ".repeat(depth)
	print("[probe] ", pad, n.name, " (", n.get_class(), ")")
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var mesh := mi.mesh
		if mesh:
			print("[probe] ", pad, "  surfaces=", mesh.get_surface_count(),
				" aabb=", mi.get_aabb(), " visible=", mi.visible)
			for i in mesh.get_surface_count():
				var mat := mesh.surface_get_material(i)
				var tri := 0
				var arr := mesh.surface_get_arrays(i)
				if arr.size() > Mesh.ARRAY_INDEX and arr[Mesh.ARRAY_INDEX] != null:
					tri = (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
				else:
					var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
					tri = v.size() / 3
				print("[probe] ", pad, "   surf ", i, " tris=", tri,
					" mat=", (mat.resource_name if mat else "<null>"))
	if n is Skeleton3D:
		var sk := n as Skeleton3D
		print("[probe] ", pad, "  bones=", sk.get_bone_count())
	if n is AnimationPlayer:
		var ap := n as AnimationPlayer
		print("[probe] ", pad, "  anims=", ap.get_animation_list())
	for c in n.get_children():
		_dump(c, depth + 1)
