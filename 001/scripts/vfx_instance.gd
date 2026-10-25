extends MeshInstance3D
## Visual-only lifetime; follows scene pause/time scale and dies with its parent.
var lifetime := 0.35
var age := 0.0
var start_scale := Vector3.ONE
var end_scale := Vector3.ONE
var drift := Vector3.ZERO
var gravity := 0.0
var spin := Vector3.ZERO
var peak_opacity := 1.0
var fade_in := 0.025
var erode := true

func _ready() -> void:
	add_to_group("combat_vfx_transient")
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	scale = start_scale
	_update_material(0.0, 0.0)

func _process(delta: float) -> void:
	age += delta
	if age >= lifetime:
		queue_free()
		return
	var t := age / lifetime
	scale = start_scale.lerp(end_scale, 1.0 - pow(1.0 - t, 2.0))
	drift.y -= gravity * delta
	position += drift * delta
	rotation += spin * delta
	var opacity := peak_opacity * minf(age / maxf(fade_in, 0.001), 1.0) * (1.0 - smoothstep(0.3, 1.0, t))
	_update_material(opacity, t)

func _update_material(opacity: float, progress: float) -> void:
	if material_override is ShaderMaterial:
		var mat := material_override as ShaderMaterial
		mat.set_shader_parameter("opacity", opacity)
		mat.set_shader_parameter("phase", age)
		mat.set_shader_parameter("dissolve", maxf(0.0, progress - 0.35) * 0.65 if erode else 0.0)
	elif material_override is StandardMaterial3D:
		(material_override as StandardMaterial3D).albedo_color.a = opacity
