extends SceneTree

func _init() -> void:
	var base := OS.get_cmdline_user_args()[0]
	var names := ["flame_tongue", "flame_flow", "water_splash", "impact_flash", "smoke", "rune_mask"]
	var results: Array = []
	var valid := true
	for name: String in names:
		var path := base.path_join("001/art/vfx/textures/" + name)
		var rgba := Image.load_from_file(path + "_rgba.png")
		var mask := Image.load_from_file(path + "_mask.png")
		if rgba == null or mask == null:
			valid = false
			results.append({"name": name, "pass": false, "reason": "missing image"})
			continue
		var width := 2048 if name == "flame_flow" else 1024
		var ok := rgba.get_width() == width and rgba.get_height() == 1024
		ok = ok and rgba.get_format() == Image.FORMAT_RGBA8
		ok = ok and mask.get_width() == width and mask.get_height() == 1024
		ok = ok and rgba.detect_alpha() == Image.ALPHA_BLEND
		for x in width:
			ok = ok and rgba.get_pixel(x, 0).a == 0 and rgba.get_pixel(x, 1023).a == 0
		for y in 1024:
			if name == "flame_flow":
				ok = ok and rgba.get_pixel(0,y).is_equal_approx(rgba.get_pixel(width-1,y))
			else:
				ok = ok and rgba.get_pixel(0,y).a == 0 and rgba.get_pixel(width-1,y).a == 0
		for y in range(0,1024,13):
			for x in range(0,width,13):
				ok = ok and absf(rgba.get_pixel(x,y).a-mask.get_pixel(x,y).r)<0.005
		results.append({"name":name,"pass":ok,"size":[width,1024],"rgba_format":rgba.get_format(),"mask_format":mask.get_format()})
		valid = valid and ok
	var report := {"pass":valid,"engine":Engine.get_version_info().string,"assets":results,
		"checks":"Godot PNG decode, dimensions, RGBA8, blended alpha, transparent borders, X seam, mask-alpha agreement"}
	var file := FileAccess.open(base.path_join("art_source/vfx_textures/godot_validation.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit(0 if valid else 1)
