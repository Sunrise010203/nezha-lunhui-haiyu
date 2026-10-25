shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled;

uniform sampler2D palace : source_color, filter_linear_mipmap, repeat_enable, hint_default_black;
uniform vec3 haze = vec3(0.025, 0.10, 0.13);

void fragment() {
	vec3 painted = texture(palace, vec2(UV.x * 12.0, clamp((UV.y - 0.41) / 0.20, 0.0, 1.0))).rgb * 0.65;
	// Fade every edge into the underwater atmosphere, not an alpha-blended wall.
	float edge = smoothstep(0.41, 0.46, UV.y) * (1.0 - smoothstep(0.55, 0.62, UV.y));
	edge *= smoothstep(0.0, 0.05, UV.x) * (1.0 - smoothstep(0.95, 1.0, UV.x));
	vec3 atmosphere = haze * mix(1.2, 0.65, smoothstep(0.0, 1.0, UV.y));
	ALBEDO = mix(atmosphere, painted, edge * 0.65);
}
