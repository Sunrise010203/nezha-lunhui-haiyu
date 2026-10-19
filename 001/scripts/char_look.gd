extends RefCounted
## 哪吒角色外观注入（P2/P3）
## 把烘焙贴图挂到 char_body.gdshader 上，并用 material_override 覆盖 toon 材质。
## 全部用 static，调用方：const CharLook := preload("res://scripts/char_look.gd")

const SHADER_PATH := "res://shaders/char_body.gdshader"
const TEX_DIR := "res://art/textures/nezha/"

const TEX_SLOTS := {
	"tex_albedo": "nezha_albedo.png",
	"tex_normal": "nezha_normal.png",
	"tex_orm": "nezha_orm.png",
	"tex_mask": "nezha_mask.png",
	"tex_thickness": "nezha_thickness.png",
	"tex_curvature": "nezha_curvature.png",
}


static func apply(model: Node3D) -> bool:
	## 成功返回 true；贴图或 shader 缺失时返回 false，角色保持原有 toon 材质（安全回退）。
	if model == null:
		return false
	var sh: Shader = load(SHADER_PATH) as Shader
	if sh == null:
		push_warning("CharLook: 找不到 " + SHADER_PATH)
		return false
	var mat := ShaderMaterial.new()
	mat.shader = sh
	for slot in TEX_SLOTS:
		var tex: Texture2D = load(TEX_DIR + TEX_SLOTS[slot]) as Texture2D
		if tex == null:
			push_warning("CharLook: 缺少贴图 " + TEX_DIR + TEX_SLOTS[slot])
			return false
		mat.set_shader_parameter(slot, tex)
	var count := 0
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = mat
		count += 1
	print("[CharLook] PBR 材质已挂载：%d 个网格" % count)
	return count > 0


static func attach_lights(parent: Node3D) -> void:
	## P3 三点光：主光（相机侧上左）+ 背轮廓光；player.gd 自带的火光当补光。
	## 全部阴影关闭——角色级小灯泡开阴影性价比太低。
	var key := OmniLight3D.new()
	key.name = "CharKey"
	key.light_color = Color(1.0, 0.955, 0.90)
	key.light_energy = 5.2
	key.omni_range = 7.5
	key.omni_attenuation = 1.2
	key.position = Vector3(1.6, 2.7, 2.4)
	key.shadow_enabled = false
	parent.add_child(key)

	var rim := OmniLight3D.new()
	rim.name = "CharRim"
	rim.light_color = Color(1.0, 0.62, 0.32)
	rim.light_energy = 3.2
	rim.omni_range = 5.0
	rim.omni_attenuation = 1.4
	rim.position = Vector3(-0.7, 2.1, -1.9)
	rim.shadow_enabled = false
	parent.add_child(rim)
