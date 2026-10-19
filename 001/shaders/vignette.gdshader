shader_type canvas_item;
// 游戏内晕影 + 低血量红晕

uniform float low_hp = 0.0;

void fragment() {
	vec2 uv = UV - 0.5;
	float d = length(uv * vec2(1.25, 1.0));
	float vig = smoothstep(0.42, 0.95, d);
	vec3 col = vec3(0.0, 0.005, 0.01);
	float a = vig * 0.55;
	// 低血量时边缘泛红呼吸
	float pulse = 0.6 + 0.4 * sin(TIME * 4.0);
	col = mix(col, vec3(0.35, 0.0, 0.0), low_hp * pulse * 0.8);
	a = max(a, vig * low_hp * 0.7 * pulse);
	COLOR = vec4(col, a);
}
