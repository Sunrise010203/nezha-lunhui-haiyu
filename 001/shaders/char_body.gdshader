shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
// 哪吒角色本体 PBR 着色器（P2）
// 贴图来自 Blender 烘焙：001/art/textures/nezha/
//   albedo(sRGB) / normal(TANGENT) / orm(R=AO G=Rough B=Metal) / mask(R=丝绸 G=皮肤 B=覆盖) / curvature / thickness
// 用法：game.gd 的 load_model() 会给角色套 toon 材质（DIFFUSE_TOON + next_pass 描边），
//       material_override 优先级高于 surface_override_material，能整体接管外观。

uniform sampler2D tex_albedo : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D tex_normal : hint_normal, filter_linear_mipmap, repeat_disable;
uniform sampler2D tex_orm : filter_linear_mipmap, repeat_disable;
uniform sampler2D tex_mask : filter_linear_mipmap, repeat_disable;
uniform sampler2D tex_thickness : filter_linear_mipmap, repeat_disable;
uniform sampler2D tex_curvature : filter_linear_mipmap, repeat_disable;

uniform float normal_depth : hint_range(0.0, 3.0) = 1.35;
uniform float ao_strength : hint_range(0.0, 1.0) = 0.55;
uniform vec3 sss_tint : source_color = vec3(0.95, 0.45, 0.34);
uniform float sss_strength : hint_range(0.0, 2.0) = 0.60;
uniform vec3 rim_color : source_color = vec3(1.0, 0.66, 0.34);
uniform float rim_strength : hint_range(0.0, 3.0) = 0.50;
uniform float rim_power : hint_range(1.0, 8.0) = 3.2;
uniform float cloth_weave : hint_range(0.0, 1.0) = 0.30;
uniform float cavity_dirt : hint_range(0.0, 1.0) = 0.22;
// 场景没有 SSR/反射探针时，纯金属会发黑发绿；金属度封顶 + 饱和度提一点保住红金辨识度
uniform float metal_cap : hint_range(0.0, 1.0) = 0.72;
uniform float alb_saturation : hint_range(0.0, 2.0) = 1.20;
uniform float alb_gain : hint_range(0.5, 2.0) = 1.06;

// 丝绸的经纬纹：UV 空间低频织法 + 交叉光泽（纯程序化，不占贴图预算）
float weave_at(vec2 uv) {
	float warp = sin(uv.x * 320.0);
	float weft = sin(uv.y * 320.0);
	float cross_ = sin((uv.x + uv.y) * 760.0);
	return warp * weft * 0.7 + cross_ * 0.3;
}

void fragment() {
	vec2 uv = UV;
	vec3 alb = texture(tex_albedo, uv).rgb;
	vec3 orm = texture(tex_orm, uv).rgb;
	vec3 mask = texture(tex_mask, uv).rgb;
	float curv = texture(tex_curvature, uv).r;

	float weave = weave_at(uv) * mask.r * cloth_weave;
	// 凹陷积灰：curvature 低 = 凹处变暗，3A 角色“脏感”的主要来源
	float cav = 1.0 - smoothstep(0.15, 0.55, curv);

	float lum = dot(alb, vec3(0.2126, 0.7152, 0.0722));
	alb = mix(vec3(lum), alb, alb_saturation) * alb_gain;
	ALBEDO = alb * (1.0 - 0.13 * weave) * (1.0 - cavity_dirt * cav * 0.42);
	METALLIC = min(orm.b, metal_cap);
	ROUGHNESS = clamp(orm.g + weave * 0.10, 0.04, 1.0);
	SPECULAR = mix(0.50, 0.62, mask.r);

	AO = mix(1.0, orm.r, ao_strength);
	AO_LIGHT_AFFECT = 0.30;

	NORMAL_MAP = texture(tex_normal, uv).rgb;
	NORMAL_MAP_DEPTH = normal_depth;

	// 皮肤次表面：铜色透光，厚度图决定红光穿透量
	SSS_STRENGTH = mask.g * sss_strength * (1.0 - orm.b);
	SSS_TRANSMITTANCE_COLOR = vec4(sss_tint, 1.0);
	SSS_TRANSMITTANCE_DEPTH = clamp(texture(tex_thickness, uv).r, 0.05, 1.0);

	// 边缘光内联进本体（金属件减半，避免金饰过曝）
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), rim_power);
	EMISSION += rim_color * rim * rim_strength * (1.0 - 0.55 * orm.b);
}
