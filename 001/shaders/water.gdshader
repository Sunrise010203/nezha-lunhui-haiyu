shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;
// 轮回海面：顶点波浪 + 菲涅尔幽光 + 流动波纹

uniform vec3 shallow_color : source_color = vec3(0.04, 0.22, 0.26);
uniform vec3 deep_color : source_color = vec3(0.005, 0.035, 0.06);
uniform float wave_height = 0.45;

varying float v_wave;
varying vec3 v_wp;

float wave(vec2 p, float t) {
	float w = 0.0;
	w += sin(p.x * 0.35 + t * 1.1) * 0.5;
	w += sin(p.y * 0.42 - t * 0.8) * 0.35;
	w += sin((p.x + p.y) * 0.21 + t * 0.6) * 0.6;
	w += sin(p.x * 1.3 - t * 1.7) * 0.12;
	return w;
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float w = wave(wp.xz, TIME);
	VERTEX.y += w * wave_height;
	v_wave = w;
	v_wp = wp;

	// 法线近似
	float e = 0.6;
	float wx = wave(wp.xz + vec2(e, 0.0), TIME) - w;
	float wz = wave(wp.xz + vec2(0.0, e), TIME) - w;
	NORMAL = normalize(vec3(-wx * wave_height / e, 1.0, -wz * wave_height / e));
}

void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 col = mix(deep_color, shallow_color, fres * 0.85 + v_wave * 0.06 + 0.1);
	// 波峰泡沫 + 水面碎光：让远处海面不是一条平线
	float crest = smoothstep(0.55, 1.15, v_wave);
	float sparkle = pow(max(0.0, sin(v_wp.x * 1.7 + TIME * 0.8) *
		sin(v_wp.z * 2.1 - TIME * 0.6)), 32.0);
	col = mix(col, vec3(0.34, 0.62, 0.62), crest * 0.22);
	ALBEDO = col;
	ROUGHNESS = 0.08;
	METALLIC = 0.0;
	SPECULAR = 0.6;
	EMISSION = vec3(0.05, 0.30, 0.32) * (fres * 0.5 + crest * 0.8) +
		vec3(0.35, 0.75, 0.75) * sparkle * 0.10;
}
