shader_type spatial;
render_mode unshaded;


// =========================
// 通用参数
// =========================
group_uniforms Common;

uniform float default_intensity = 0.7;

group_uniforms;


// =========================
// 贴图参数
// =========================
group_uniforms Textures;

uniform sampler2D albedo_tex;
uniform sampler2D ao_tex;

group_uniforms;


// =========================
// 日行灯
// =========================
group_uniforms DRL;

uniform bool drl = false;
uniform float drl_intensity = 5.0;

group_uniforms;


// =========================
// 近光灯
// =========================
group_uniforms LowBeam;

uniform bool low_beam = false;
uniform float low_beam_intensity = 1.5;

group_uniforms;


// =========================
// 远光灯
// =========================
group_uniforms HighBeam;

uniform bool high_beam = false;
uniform float high_beam_intensity = 5.0;

group_uniforms;


// =========================
// 双闪灯
// =========================
group_uniforms HazardLight;

uniform bool hazardlight = false;
uniform vec3 hazardlight_color : source_color = vec3(1.0, 0.682, 0.0); // #FFAE00
uniform float hazardlight_intensity = 5.0;

group_uniforms;


// =========================
// 刹车灯
// =========================
group_uniforms BrakeLight;

uniform bool brake_light = false;
uniform vec3 color_tint : source_color = vec3(1.0); // 刹车灯颜色
uniform float brake_light_on_intensity = 5.0;

group_uniforms;


// =========================
// 后雾灯
// =========================
group_uniforms RearFogLight;

uniform bool rear_fog_light = false;
uniform float rear_fog_light_intensity = 5.0;

group_uniforms;


// =========================
// 效果参数
// =========================
group_uniforms Effects;

uniform float emission_intensity = 1.0;
uniform float ao_strength = 1.0;

group_uniforms;


void fragment() {
	vec3 albedo = texture(albedo_tex, UV).rgb;

	// AO
	float ao = texture(ao_tex, UV).r;
	ao = mix(1.0, ao, ao_strength);

	vec3 tint = vec3(1.0);
	float light_intensity = default_intensity;

	// 双闪开启时自动启用近光
	bool low_beam_active = low_beam || hazardlight;

	// 日行灯
	if (drl) {
		light_intensity = drl_intensity; // 5.0
	}

	// 近光
	if (low_beam_active) {
		light_intensity = low_beam_intensity;
	}

	// 双闪
	if (hazardlight) {
		tint = hazardlight_color;
		light_intensity = hazardlight_intensity;
	}

	// 远光
	if (high_beam) {
		light_intensity = high_beam_intensity;
	}

	// 后雾灯
	if (rear_fog_light) {
		tint = vec3(1.0, 0.0, 0.0);
		light_intensity = rear_fog_light_intensity;
	}

	// 刹车灯，优先级最高
	if (brake_light) {
		tint = color_tint;
		light_intensity = brake_light_on_intensity;
	}

	vec3 final_color = albedo * tint * light_intensity * ao;

	ALBEDO = final_color;

	EMISSION = (drl || low_beam_active || high_beam || hazardlight || rear_fog_light || brake_light)
		? final_color * emission_intensity
		: vec3(0.0);
}
