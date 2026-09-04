shader_type spatial;
render_mode unshaded, world_vertex_coords;

// ============================================================
// Common
// ============================================================

const float EPSILON = 1e-6;
const float DIELECTRIC_F0 = 0.04;
const vec3  WORLD_UP = vec3(0.0, 1.0, 0.0);

const vec3 AP1_RGB2Y = vec3(
	0.2722287168,
	0.6740817658,
	0.0536895174
);

varying vec3 v_world_position;


// ============================================================
// Uniforms: Environment
// ============================================================

group_uniforms Env;

uniform samplerCube prefiltered_map;
uniform samplerCube irradiance_map;
uniform float env_rotate = 0.0;


// ============================================================
// Uniforms: Base Color
// ============================================================

group_uniforms Base_Color;

uniform sampler2D Basecolor_Tex;
uniform float Basecolor_UV = 1.0;

uniform vec3 BaseColorCenter : source_color = vec3(1.0);
uniform vec3 BaseColorEdge   : source_color = vec3(0.75);

uniform float BaseColor_Fresnel_Exponent = 2.0;
uniform float BaseColor_Fresnel_Falloff  = 0.04;
uniform float BaseColor_Fresnel_Power    = 1.0;


// ============================================================
// Uniforms: ORS
// ORS_Tex: R = AO, G = Roughness, B = Shadow
// ============================================================

group_uniforms ORS;

uniform sampler2D ORS_Tex;

uniform float ao_Min : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float ao_Max : hint_range(0.0, 1.0, 0.01) = 1.0;

uniform float roughness_Min : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float roughness_Max : hint_range(0.0, 1.0, 0.01) = 0.5;

uniform float shadow_Min : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float shadow_Max : hint_range(0.0, 1.0, 0.01) = 1.0;


// ============================================================
// Uniforms: Normal
// ============================================================

group_uniforms Normal;

uniform bool useN = false;
uniform sampler2D Normal_Tex;
uniform float NormalUV = 1.0;
uniform float normalIntensity : hint_range(0.0, 1.0, 0.01) = 0.5;


// ============================================================
// Uniforms: Material Attributes
// ============================================================

group_uniforms Attributes;

uniform float Metallic : hint_range(0.0, 1.0, 0.01) = 0.0;

uniform float diffuseIntensity = 1.0;
uniform float specularIntensity = 1.0;

uniform bool useClearcoat = false;
uniform float clearcoat_Intensity = 1.0;


// ============================================================
// Uniforms: Film ToneMap
// ============================================================

group_uniforms Film;

uniform float slope = 0.88;
uniform float toe = 0.55;
uniform float shoulder = 0.26;
uniform float blackclip = 0.0;
uniform float whiteclip = 0.04;


// ============================================================
// Basic Helpers
// ============================================================

float saturate(float x) {
	return clamp(x, 0.0, 1.0);
}

vec3 saturate_vec3(vec3 x) {
	return clamp(x, vec3(0.0), vec3(1.0));
}

float log10_safe(float x) {
	return log(max(x, EPSILON)) / log(10.0);
}

vec3 log10_safe_vec3(vec3 x) {
	return log(max(x, vec3(EPSILON))) / log(10.0);
}

vec3 select_vec3(bvec3 condition, vec3 a, vec3 b) {
	return vec3(
		condition.x ? a.x : b.x,
		condition.y ? a.y : b.y,
		condition.z ? a.z : b.z
	);
}


// ============================================================
// Film ToneMap
// ============================================================

vec3 FilmToneMap_Simplified(
	vec3 LinearColor,
	float FilmSlope,
	float FilmToe,
	float FilmShoulder,
	float FilmBlackClip,
	float FilmWhiteClip
) {
	vec3 C = max(LinearColor, vec3(0.0));

	// Pre desaturate
	float Y = dot(C, AP1_RGB2Y);
	C = mix(vec3(Y), C, 0.96);

	float ToeScale = 1.0 + FilmBlackClip - FilmToe;
	float ShoulderScale = 1.0 + FilmWhiteClip - FilmShoulder;

	const float InMatch = 0.18;
	const float OutMatch = 0.18;

	float ToeMatch;

	if (FilmToe > 0.8) {
		ToeMatch = (1.0 - FilmToe - OutMatch) / FilmSlope + log10_safe(InMatch);
	} else {
		float bt = (OutMatch + FilmBlackClip) / ToeScale - 1.0;
		bt = clamp(bt, -0.999, 0.999);

		ToeMatch =
			log10_safe(InMatch)
			- 0.5 * log((1.0 + bt) / (1.0 - bt)) * (ToeScale / FilmSlope);
	}

	float StraightMatch = (1.0 - FilmToe) / FilmSlope - ToeMatch;
	float ShoulderMatch = FilmShoulder / FilmSlope - StraightMatch;

	vec3 LogColor = log10_safe_vec3(C);

	vec3 StraightColor = FilmSlope * (LogColor + vec3(StraightMatch));

	vec3 ToeColor =
		vec3(-FilmBlackClip)
		+ (2.0 * ToeScale)
		/ (1.0 + exp(((-2.0 * FilmSlope) / ToeScale) * (LogColor - vec3(ToeMatch))));

	vec3 ShoulderColor =
		vec3(1.0 + FilmWhiteClip)
		- (2.0 * ShoulderScale)
		/ (1.0 + exp(((2.0 * FilmSlope) / ShoulderScale) * (LogColor - vec3(ShoulderMatch))));

	bvec3 inToe = lessThan(LogColor, vec3(ToeMatch));
	bvec3 inShoulder = greaterThan(LogColor, vec3(ShoulderMatch));

	vec3 t = saturate_vec3((LogColor - vec3(ToeMatch)) / vec3(ShoulderMatch - ToeMatch));

	if (ShoulderMatch < ToeMatch) {
		t = vec3(1.0) - t;
	}

	t = (3.0 - 2.0 * t) * t * t;

	vec3 ToneColor = mix(ToeColor, ShoulderColor, t);
	ToneColor = select_vec3(inToe, ToeColor, ToneColor);
	ToneColor = select_vec3(inShoulder, ShoulderColor, ToneColor);

	// Post desaturate
	float TY = dot(ToneColor, AP1_RGB2Y);
	ToneColor = mix(vec3(TY), ToneColor, 0.93);

	return max(ToneColor, vec3(0.0));
}


// ============================================================
// IBL / BRDF Helpers
// ============================================================

vec2 approximateEnvironmentBrdfCoefficients(
	float roughness,
	float normalDotView
) {
	vec4 c0 = vec4(-1.0, -0.0275, -0.572, 0.022);
	vec4 c1 = vec4( 1.0,  0.0425,  1.040, -0.040);

	vec4 r = roughness * c0 + c1;

	float a004 =
		min(r.x * r.x, exp2(-9.28 * normalDotView)) * r.x
		+ r.y;

	return vec2(-1.04, 1.04) * a004 + r.zw;
}

float approximateCoatingEnvironmentFresnel(
	float coatingRoughness,
	float normalDotView,
	float coatingAmount
) {
	vec2 ab = approximateEnvironmentBrdfCoefficients(
		coatingRoughness,
		normalDotView
	);

	float coatingF = DIELECTRIC_F0 * ab.x + ab.y;

	return saturate(coatingF * coatingAmount);
}

float computeSpecularOcclusion(
	float normalDotView,
	float roughness,
	float ambientOcclusion
) {
	float r2 = roughness * roughness;

	return saturate(
		pow(abs(normalDotView + ambientOcclusion), r2)
		- 1.0
		+ ambientOcclusion
	);
}

vec3 bendReflectionTowardNormal(
	vec3 normal,
	vec3 reflectionDir,
	float roughness
) {
	float a = roughness * roughness;
	float weight = (1.0 - a) * (sqrt(1.0 - a) + a);

	return normalize(mix(normal, reflectionDir, weight));
}

vec3 rotateVectorAroundAxis(
	vec3 v,
	vec3 axis,
	float theta
) {
	axis = normalize(axis);

	float c = cos(theta);
	float s = sin(theta);

	return
		v * c
		+ cross(axis, v) * s
		+ axis * dot(axis, v) * (1.0 - c);
}


// ============================================================
// Vertex
// ============================================================

void vertex() {
	v_world_position = VERTEX;
}


// ============================================================
// Fragment
// ============================================================

void fragment() {
	// ------------------------------------------------------------
	// View / Normal
	// ------------------------------------------------------------

	vec3 V = normalize(CAMERA_POSITION_WORLD - v_world_position);

	// Godot fragment normal is usually in view space, so convert to world space.
	vec3 geomN = normalize((vec4(NORMAL,0)*VIEW_MATRIX).rgb);;
	vec3 N = geomN;

	if(useN)
	{

    vec3 map_n = texture(Normal_Tex, UV * NormalUV).rgb * 2.0 - 1.0;
    map_n.g = -map_n.g; 
    map_n = mix(vec3(0.0, 0.0, 1.0), map_n, normalIntensity);
    
    vec3 T = normalize((vec4(TANGENT,0)*VIEW_MATRIX).rgb);
    vec3 B = normalize((vec4(BINORMAL,0)*VIEW_MATRIX).rgb);
    vec3 GeomN = normalize((vec4(NORMAL,0)*VIEW_MATRIX).rgb);
    mat3 TBN = mat3(T, B, GeomN);
    
    N = normalize(TBN * map_n);
	}

	float NdotV = saturate(dot(N, V));


	// ------------------------------------------------------------
	// Texture Inputs
	// ------------------------------------------------------------

	vec3 ors = texture(ORS_Tex, UV).rgb;

	float ao = mix(ao_Min, ao_Max, ors.r);
	float roughness = mix(roughness_Min, roughness_Max, ors.g);
	float shadow = mix(shadow_Min, shadow_Max, ors.b);

	vec3 baseTex = texture(Basecolor_Tex, UV * Basecolor_UV).rgb;


	// ------------------------------------------------------------
	// Base Color Fresnel
	// ------------------------------------------------------------

	float baseFresnel =
		pow(1.0 - NdotV, BaseColor_Fresnel_Exponent)
		* (1.0 - BaseColor_Fresnel_Falloff)
		+ BaseColor_Fresnel_Falloff;

	vec3 edgeColor = mix(
		BaseColorCenter,
		BaseColorEdge,
		BaseColor_Fresnel_Power
	);

	vec3 BaseColor = mix(
		BaseColorCenter,
		edgeColor,
		baseFresnel
	) * baseTex;


	// ------------------------------------------------------------
	// Material Layers
	// ------------------------------------------------------------

	vec3 baseDiffuseColor = BaseColor * (1.0 - Metallic);
	vec3 baseSpecularColor = mix(vec3(DIELECTRIC_F0), BaseColor, Metallic);

	float layerAttenuation = 1.0;
	float coatingFresnel = 0.0;

	if (useClearcoat) {
		coatingFresnel = approximateCoatingEnvironmentFresnel(
			0.04,
			NdotV,
			clearcoat_Intensity
		);

		layerAttenuation = 1.0 - coatingFresnel;
		baseSpecularColor *= layerAttenuation;
	}


	// ------------------------------------------------------------
	// IBL Directions
	// ------------------------------------------------------------

	vec3 R = reflect(-V, N);

	vec3 baseIblDir = bendReflectionTowardNormal(
		N,
		R,
		roughness
	);

	// 旋转环境贴图采样方向。
	//R = rotateVectorAroundAxis(R, WORLD_UP, env_rotate);
	baseIblDir = rotateVectorAroundAxis(baseIblDir, WORLD_UP, env_rotate);

	vec3 diffuseIblDir = rotateVectorAroundAxis(N, WORLD_UP, env_rotate);


	// ------------------------------------------------------------
	// Diffuse IBL
	// ------------------------------------------------------------

	vec3 skyDiffuse = texture(irradiance_map, diffuseIblDir).rgb;

	vec3 diffuseAmbient =
		skyDiffuse
		* baseDiffuseColor
		* ao
		* diffuseIntensity;
	// ------------------------------------------------------------
	// Specular IBL
	// ------------------------------------------------------------
	vec3 baseSkyReflection =
		textureLod(prefiltered_map, baseIblDir, roughness * 7.0).rgb;

	vec2 baseAB = approximateEnvironmentBrdfCoefficients(
		roughness,
		NdotV
	);

	float baseScalar = saturate(50.0 * baseSpecularColor.g);

	vec3 baseLayerBrdf =
		baseSpecularColor * baseAB.x
		+ baseAB.y * baseScalar;

	if (useClearcoat) {
		baseLayerBrdf =
			baseSpecularColor * baseAB.x
			+ baseAB.y
			* baseScalar
			* saturate(1.0 - clearcoat_Intensity);
	}

	vec3 baseSpecularAmbient =
		baseSkyReflection
		* layerAttenuation
		* baseLayerBrdf
		* specularIntensity;
	// ------------------------------------------------------------
	// Clearcoat IBL
	// ------------------------------------------------------------
	float baseSpecularOcclusion = computeSpecularOcclusion(
		NdotV,
		roughness,
		ao
	);

	vec3 finalColor = diffuseAmbient + baseSpecularAmbient;

	if (useClearcoat) {
		vec3 CN = normalize((vec4(NORMAL,0)*VIEW_MATRIX).rgb);
		vec3 CR = normalize(reflect(-V, CN));
		CR = rotateVectorAroundAxis(CR, WORLD_UP, env_rotate);
		vec3 coatingSpecularAmbient =
			textureLod(prefiltered_map, CR, 0.0).rgb
			* coatingFresnel
			* baseSpecularOcclusion
			* specularIntensity;

		finalColor += coatingSpecularAmbient;
		//finalColor =  baseSkyReflection;
	}


	// ------------------------------------------------------------
	// Output
	// ------------------------------------------------------------

	ALBEDO = FilmToneMap_Simplified(
		finalColor,
		slope,
		toe,
		shoulder,
		blackclip,
		whiteclip
	);
}
