shader_type sky;
// 轮回海域天穹：海渊上方的幽暗天光 + 冷月 + 缓动光带

float hash(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

void sky() {
	vec3 dir = EYEDIR;
	float h = dir.y;

	vec3 deep = vec3(0.004, 0.016, 0.030);
	vec3 horizon = vec3(0.030, 0.110, 0.135);
	vec3 zenith = vec3(0.008, 0.040, 0.075);

	vec3 col;
	if (h > 0.0) {
		col = mix(horizon, zenith, pow(clamp(h, 0.0, 1.0), 0.55));
	} else {
		col = mix(horizon, deep, pow(clamp(-h, 0.0, 1.0), 0.5));
	}

	// 冷月
	vec3 moon_dir = normalize(vec3(-0.35, 0.55, -0.75));
	float md = dot(dir, moon_dir);
	float moon = smoothstep(0.9985, 0.9995, md);
	float halo = pow(max(md, 0.0), 60.0) * 0.35;
	col += vec3(0.75, 0.9, 0.95) * moon * 2.0;
	col += vec3(0.25, 0.5, 0.55) * halo;

	// 缓动的极光式光带（归墟灵气）
	float band = sin(dir.x * 4.0 + TIME * 0.12) *
		sin(dir.z * 3.0 - TIME * 0.07);
	float band_mask = smoothstep(0.15, 0.55, h) * smoothstep(0.95, 0.5, h);
	col += vec3(0.04, 0.16, 0.14) * max(band, 0.0) * band_mask * 0.8;

	// 星屑
	if (h > 0.05) {
		vec2 sp = dir.xz / (dir.y + 0.4) * 40.0;
		float star = step(0.992, hash(floor(sp)));
		float tw = 0.5 + 0.5 * sin(TIME * 2.0 + hash(floor(sp) + 7.0) * 30.0);
		col += vec3(0.5, 0.7, 0.75) * star * tw * 0.4 * smoothstep(0.05, 0.3, h);
	}

	COLOR = col;
}
