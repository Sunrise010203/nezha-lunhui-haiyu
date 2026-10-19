extends SceneTree
## 能力探针：确认本机 Godot 版本里某批类/API 是否存在。
## 用途：换版本或引入新流程（重定向 / 弹簧骨骼 / 动画树）前，先确认 API 在不在，
##       免得照着文档写了一段代码、运行时才发现类不存在。
## 用法（注意：先让 APPDATA 可写，否则 Godot 写 user:// 日志会失败甚至崩溃）：
##   $env:APPDATA = 'E:\godot_game_by_fable\_tmp_appdata'
##   & '<Godot>' --headless --path 'E:\godot_game_by_fable\001' --script res://tools/_probe_caps.gd

const CLASSES := [
	# 骨骼动画 / 重定向
	"RetargetModifier3D", "SkeletonProfileHumanoid", "BoneMap",
	"SkeletonModifier3D", "SpringBoneSimulator3D", "PhysicalBoneSimulator3D",
	"AnimationTree", "AnimationNodeBlendSpace1D", "AnimationNodeBlendSpace2D",
	"AnimationNodeStateMachine", "AnimationNodeOneShot",
	# 导入 / 资源
	"GLTFDocument", "GLTFState",
	# 渲染 / 光照 / 批量
	"MultiMeshInstance3D", "LightmapGI", "ReflectionProbe", "VoxelGI", "OccluderInstance3D",
]


func _initialize() -> void:
	var v := Engine.get_version_info()
	print("ENGINE version=%s hash=%s" % [v.string, v.hash])
	var missing: Array[String] = []
	for n in CLASSES:
		var ok := ClassDB.class_exists(n)
		print("CAP %-28s %s" % [n, "yes" if ok else "NO"])
		if not ok:
			missing.append(n)
	print("CAP_MISSING %s" % [missing])
	quit()
