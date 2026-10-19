shader_type spatial;
// 敌人/Boss 的轮廓光叠加层（用作 material_overlay）
// 目的：深色模型在深色背景里"不可见"——加一圈菲涅尔边缘光，不改变本体材质。
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 rim_color : source_color = vec4(0.5, 0.85, 1.0, 1.0);
uniform float rim_power = 2.2;
uniform float rim_strength = 1.0;

void fragment() {
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	ALBEDO = rim_color.rgb * rim_strength;
	ALPHA = clamp(f * rim_strength, 0.0, 1.0) * rim_color.a;
}
