shader_type spatial;
// P1 §4.10 水下体积光柱：一张朝相机的水面光柱四边形，加法混合。
// blend_add 下把强度烘进 ALBEDO，避免某些管线忽略 alpha 后出现实心亮带。
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 tint : source_color = vec3(0.35, 0.80, 0.85);
uniform float strength = 0.10;
uniform float seed = 0.0;

void fragment() {
	vec2 uv = UV;
	// 横向用 sin^2 做柔和光束，四边都趋零——绝不出现可见的矩形边
	float edge = sin(uv.x * 3.14159265);
	edge *= edge;
	float fade = smoothstep(0.0, 0.22, uv.y) * smoothstep(1.0, 0.65, uv.y);
	float flow = 0.55 + 0.45 * sin(uv.y * 9.0 - TIME * 0.55 + seed);
	float ribbon = 0.70 + 0.30 * sin(uv.x * 7.0 + seed * 2.0 + TIME * 0.2);
	ALBEDO = tint * edge * fade * flow * ribbon * strength;
	ALPHA = 1.0;
}
