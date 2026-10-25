shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform sampler2D effect_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 tint : source_color = vec4(0.35, 0.4, 0.43, 0.4);
uniform float opacity = 1.0;
uniform float phase = 0.0;
uniform float dissolve = 0.0;
void fragment() {
	vec4 texel = texture(effect_tex, UV);
	ALBEDO = tint.rgb;
	ALPHA = texel.a * tint.a * opacity;
}
