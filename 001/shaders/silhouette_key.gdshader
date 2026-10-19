shader_type spatial;
// 把"白底黑剪影"图直接抠成不透明剪影：白色透明、黑色实心。
// 用 alpha scissor 而不是透明混合——避免多层透明面片的排序/不可见问题。
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled;

uniform sampler2D tex : source_color, filter_linear, repeat_disable;
uniform vec4 tint : source_color = vec4(0.02, 0.05, 0.06, 1.0);
uniform float threshold : hint_range(0.2, 0.95) = 0.55;
uniform float feather : hint_range(0.0, 0.25) = 0.06;
uniform vec2 uv_scale = vec2(1.0, 1.0);
uniform vec2 uv_offset = vec2(0.0, 0.0);

void fragment() {
	vec4 c = texture(tex, UV * uv_scale + uv_offset);
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	float a = smoothstep(threshold - feather, threshold + feather, 1.0 - lum);
	ALBEDO = tint.rgb;
	ALPHA = a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
