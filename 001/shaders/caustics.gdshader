shader_type spatial;
// 水下焦散：两条程序化噪声的"等值线"相减，得到细亮丝，而不是大块光斑。
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.35, 0.80, 0.85, 1.0);
uniform float strength = 0.10;
uniform vec2 scroll = vec2(0.018, 0.011);

varying vec2 wuv;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	wuv = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 p = wuv * 3.2 + TIME * scroll;
	float a = noise2(p * 2.0 + TIME * 0.03);
	float b = noise2(p * 3.1 - TIME * 0.02 + 13.0);
	float d = abs(a - b);
	float c = pow(1.0 - smoothstep(0.0, 0.18, d), 3.0);
	ALBEDO = tint.rgb;
	ALPHA = clamp(c * strength, 0.0, 1.0);
}
