shader_type spatial;
// 远景贴片（漩涡/光效）专用：加法混合 + 径向淡出
// 原实现直接用 QuadMesh + 不透明黑底 PNG + BLEND_ADD，方形边界会变成一块
// 发亮的多边形（截图里那块洋红色三角）。这里用径向遮罩把方形边缘化开。
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float fade_start = 0.30;
uniform float fade_end = 0.52;
uniform float strength = 1.0;

void fragment() {
	vec2 d = UV - 0.5;
	float r = length(d) * 2.0;
	float mask = 1.0 - smoothstep(fade_start, fade_end, r);
	vec3 c = texture(tex, UV).rgb * tint.rgb * strength;
	ALBEDO = c;
	ALPHA = mask;
}
