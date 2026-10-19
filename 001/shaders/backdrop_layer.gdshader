shader_type spatial;
// DEBUG: 硬编码不透明，确认 ShaderMaterial 路径是否渲染。
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D tex : source_color, filter_linear;
uniform vec3 tint : source_color = vec3(1.0);
uniform float layer_alpha = 1.0;

void fragment() {
	ALBEDO = texture(tex, UV).rgb * tint;
	ALPHA = 1.0;
}
