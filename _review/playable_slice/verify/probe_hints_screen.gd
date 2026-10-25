extends SceneTree

func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/level_1.tscn")
	var level = scene.instantiate()
	root.add_child(level)
	await process_frame
	await process_frame
	var player = level.get("player")
	var cam = level.get("cam")
	var hints = level.get("_hints")
	print("HINTS=", hints.size())
	var vp := root.get_viewport()
	print("VIEWPORT=", vp.get_visible_rect().size)
	for h in hints:
		var pos: Vector3 = h["pos"]
		player.global_position = pos
		if player is CharacterBody3D:
			(player as CharacterBody3D).velocity = Vector3.ZERO
		if cam != null and cam.has_method("snap_to_target"):
			cam.call("snap_to_target")
		await process_frame
		await process_frame
		var label: Label3D = h["label"]
		var aabb: AABB = label.get_aabb()
		var minx := 1e9; var maxx := -1e9; var miny := 1e9; var maxy := -1e9
		for i in 8:
			var corner := aabb.position + Vector3(
				aabb.size.x if (i & 1) else 0.0,
				aabb.size.y if (i & 2) else 0.0,
				aabb.size.z if (i & 4) else 0.0)
			var wp: Vector3 = label.global_transform * corner
			var sp: Vector2 = cam.unproject_position(wp)
			minx = min(minx, sp.x); maxx = max(maxx, sp.x)
			miny = min(miny, sp.y); maxy = max(maxy, sp.y)
		print("HINT x=%.1f aabb=%s screen=[%.0f,%.0f,%.0f,%.0f] vis=%s text=%s" % [
			pos.x, str(aabb), minx, miny, maxx, maxy, label.visible, label.text])
	quit()
