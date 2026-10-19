shader_type spatial;
// 贴地接触阴影：黑色半透明径向渐变（alpha 混合）。
// 不要用 blend_mul + 纯色四边形：一旦强度/尺寸逻辑出错就会露出可见的黑方块。
// 这里 ALPHA 在边缘归零，四边形边界永远不可见。
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform float strength : hint_range(0.0, 1.0) = 0.55;
uniform float softness : hint_range(0.0, 1.0) = 0.7;

void fragment() {
	vec2 d = UV - 0.5;
	float r = length(d) * 2.0;
	float m = 1.0 - smoothstep(1.0 - softness, 1.0, r);
	ALBEDO = vec3(0.0);
	ALPHA = clamp(m * strength, 0.0, 1.0);
}
