shader_type canvas_item;
// 每章"银幕分级"：暗部/亮部双色分离 + 对比/饱和 + 暗角 + 细颗粒。
// 放在 CanvasLayer.layer=0（HUD 在 layer 1），只影响 3D 画面，不污染 UI。
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

uniform vec3 shadow_tint : source_color = vec3(0.86, 1.0, 1.06);
uniform vec3 high_tint : source_color = vec3(1.06, 1.0, 0.90);
uniform float saturation = 1.04;
uniform float contrast = 1.04;
uniform float vignette = 0.30;
uniform float grain = 0.012;

void fragment() {
	vec3 c = textureLod(screen_tex, SCREEN_UV, 0.0).rgb;
	c = (c - 0.5) * contrast + 0.5;
	float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
	c = mix(vec3(l), c, saturation);
	c *= mix(shadow_tint, high_tint, smoothstep(0.15, 0.75, l));
	float d = length(SCREEN_UV - 0.5) * 1.5;
	c *= 1.0 - vignette * smoothstep(0.35, 1.0, d);
	float n = fract(sin(dot(SCREEN_UV * vec2(1920.0, 1080.0),
		vec2(12.9898, 78.233))) * 43758.5453);
	c += (n - 0.5) * grain;
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
