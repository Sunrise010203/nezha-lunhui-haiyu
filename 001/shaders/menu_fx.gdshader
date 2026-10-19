shader_type canvas_item;
render_mode blend_add;
// 主菜单特效叠加层（加法混合）：光柱 + 漂浮灵尘 + 乾坤金环脉动

uniform float ring_y = 0.40;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * 0.18;
	vec3 col = vec3(0.0);

	// 顶部斜射光柱
	for (int i = 0; i < 5; i++) {
		float fi = float(i);
		float x0 = fract(fi * 0.27 + t * 0.05) * 1.4 - 0.2;
		float band = uv.x - x0 + uv.y * 0.35;
		float ray = exp(-band * band * 220.0) * (1.0 - uv.y * 1.1);
		ray *= 0.5 + 0.5 * sin(TIME * 0.7 + fi * 2.1);
		col += vec3(0.10, 0.30, 0.33) * max(ray, 0.0) * 0.22;
	}

	// 乾坤金环（标题后方的发光环）
	vec2 ar = vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	vec2 cuv = (uv - vec2(0.5, ring_y)) * ar;
	float r = length(cuv);
	float pulse = 0.75 + 0.25 * sin(TIME * 1.3);
	float ring = exp(-pow((r - 0.30) * 26.0, 2.0));
	col += vec3(0.95, 0.62, 0.18) * ring * 0.30 * pulse;
	float ring2 = exp(-pow((r - 0.34) * 60.0, 2.0));
	col += vec3(0.9, 0.4, 0.1) * ring2 * 0.18 * pulse;

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
			col += vec3(0.35, 0.75, 0.7) * star * 0.4 *
				(0.5 + 0.5 * sin(TIME * 2.0 + h * 40.0));
		}
	}

	COLOR = vec4(col, 1.0);
}
