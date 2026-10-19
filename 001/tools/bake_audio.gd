extends SceneTree
## 离线烘焙工具：把程序化合成音效写成 res://audio/*.res
## 用法：
##   & '<Godot>' --headless --path 'E:\godot_game_by_fable\001' --script res://tools/bake_audio.gd
## 只在音效参数改动后需要重跑；运行时 Game 会优先加载烘焙结果。

func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	var n := AudioSynth.bake_all()
	print("[bake_audio] 写出 %d 个资源 -> res://audio/ 用时 %d ms" % [n, Time.get_ticks_msec() - t0])
	quit(0 if n > 0 else 1)
