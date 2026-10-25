shader_type spatial;
render_mode cull_disabled;

varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	VERTEX.y += sin(world_xz.x * 0.8 + TIME * 0.4) * 0.025;
}

void fragment() {
	float a = sin(world_xz.x * 1.6 + world_xz.y * 1.1 + TIME * 0.55);
	float b = cos(world_xz.y * 2.1 - world_xz.x * 0.5 - TIME * 0.4);
	NORMAL_MAP = normalize(vec3(a * 0.07, b * 0.07, 1.0)) * 0.5 + 0.5;
	ALBEDO = vec3(0.018, 0.068, 0.079);
	ROUGHNESS = 0.18;
	METALLIC = 0.25;
	SPECULAR = 0.65;
}
