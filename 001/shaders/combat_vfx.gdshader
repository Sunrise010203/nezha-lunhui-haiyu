shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D effect_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform float glow = 0.65;
uniform float phase = 0.0;
uniform float scroll = 0.0;
uniform bool strip = false;
uniform bool axial = false;
uniform float dissolve = 0.0;

void fragment() {
	vec2 uv = axial ? UV.yx : UV;
	float edge = 1.0;
	if (strip) {
		edge = smoothstep(0.0, 0.12, uv.y) * (1.0 - smoothstep(0.88, 1.0, uv.y));
		uv.y = mix(0.23, 0.77, uv.y);
	}
	uv.x += phase * scroll;
	vec4 sample_color = texture(effect_tex, uv);
	float erode = smoothstep(dissolve - 0.10, dissolve + 0.10, sample_color.a);
	ALBEDO = sample_color.rgb * tint.rgb;
	EMISSION = ALBEDO * glow;
	ALPHA = sample_color.a * tint.a * opacity * edge * erode;
}
