shader_type canvas_item;
// 主菜单背景：深海渊流 + 光柱 + 漂浮灵尘 + 乾坤金环

uniform float ring_y = 0.40;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		v += amp * noise(p);
		p *= 2.1;
		amp *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * 0.18;

	// 垂直深海渐变
	vec3 deep = vec3(0.004, 0.018, 0.034);
	vec3 mid = vec3(0.015, 0.075, 0.115);
	vec3 glow_c = vec3(0.05, 0.22, 0.27);
	vec3 col = mix(mid, deep, smoothstep(0.0, 1.0, uv.y));

	// 流动的暗涌
	float swirl = fbm(uv * vec2(3.0, 4.5) + vec2(t * 0.6, -t * 0.35));
	col += glow_c * swirl * 0.22 * (1.0 - uv.y);

	// 顶部斜射光柱
	for (int i = 0; i < 5; i++) {
		float fi = float(i);
		float x0 = fract(fi * 0.27 + t * 0.05) * 1.4 - 0.2;
		float band = uv.x - x0 + uv.y * 0.35;
		float ray = exp(-band * band * 220.0) * (1.0 - uv.y * 1.1);
		ray *= 0.5 + 0.5 * sin(TIME * 0.7 + fi * 2.1);
		col += vec3(0.10, 0.30, 0.33) * max(ray, 0.0) * 0.35;
	}

	// 乾坤金环（标题后方的发光环）
	vec2 ar = vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	vec2 cuv = (uv - vec2(0.5, ring_y)) * ar;
	float r = length(cuv);
	float ring = exp(-pow((r - 0.30) * 26.0, 2.0));
	float pulse = 0.75 + 0.25 * sin(TIME * 1.3);
	col += vec3(0.95, 0.62, 0.18) * ring * 0.5 * pulse;
	float ring2 = exp(-pow((r - 0.34) * 60.0, 2.0));
	col += vec3(0.9, 0.4, 0.1) * ring2 * 0.3 * pulse;
	// 环内微光
	col += vec3(0.5, 0.3, 0.1) * exp(-r * r * 14.0) * 0.10 * pulse;

	// 漂浮灵尘
	for (int i = 0; i < 3; i++) {
		float fi = float(i) + 1.0;
		vec2 gp = uv * (22.0 + fi * 14.0);
		gp.y += TIME * (0.25 + fi * 0.12);
		gp.x += sin(TIME * 0.4 + fi) * 0.4;
		vec2 id = floor(gp);
		vec2 gf = fract(gp) - 0.5;
		float h = hash21(id + fi * 17.0);
		if (h > 0.93) {
			float d = length(gf - (vec2(h, fract(h * 7.0)) - 0.5) * 0.6);
			float star = exp(-d * d * 90.0);
			col += vec3(0.35, 0.75, 0.7) * star * 0.5 *
				(0.5 + 0.5 * sin(TIME * 2.0 + h * 40.0));
		}
	}

	// 晕影
	float vig = smoothstep(1.25, 0.35, length(uv - 0.5) * 1.6);
	col *= 0.45 + 0.55 * vig;

	COLOR = vec4(col, 1.0);
}
