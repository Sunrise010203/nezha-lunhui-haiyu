shader_type spatial;
// 角色/Boss 反向外扩描边：只渲染背面并沿法线膨胀，形成 1~2px 的深色轮廓。
// 注意：只给非骨骼模型用；骨骼模型（哪吒）走 toon + rim，避免描边停在 bind pose。
render_mode unshaded, cull_front, depth_draw_never, shadows_disabled;

uniform vec4 outline_color : source_color = vec4(0.02, 0.03, 0.05, 1.0);
uniform float width = 0.015;

void vertex() {
	VERTEX += NORMAL * width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
