shader_type spatial;
render_mode unshaded, world_vertex_coords,depth_draw_never;

// ============================================================
// Common
// ============================================================
const float DIELECTRIC_F0 = 0.04;
const vec3  WORLD_UP = vec3(0.0, 1.0, 0.0);
varying vec3 v_world_position;

// ============================================================
// Uniforms: Environment
// ============================================================

group_uniforms Env;

uniform samplerCube prefiltered_map;
uniform samplerCube irradiance_map;
uniform float env_rotate = 0.0;
uniform float uExposureEV;


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
// Basic Helpers
// ============================================================

float saturate(float x) {
	return clamp(x, 0.0, 1.0);
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


// ------------------------------------------------------------
// ACES RRT + ODT 拟合曲线
// ------------------------------------------------------------

vec3 rrtAndOdtFit(vec3 v)
{
    vec3 a = v * (v + 0.0245786) - 0.000090537;
    vec3 b = v * (0.983729 * v + 0.4329510) + 0.238081;
    return a / b;
}

vec3 acesFitted(vec3 color)
{
    // Linear sRGB / Rec.709
    // -> XYZ
    // -> D65 到 D60 白点适配
    // -> AP1 / ACEScg
    // -> RRT 饱和度调整

    const mat3 acesInputMat = mat3(
        vec3(0.59719, 0.07600, 0.02840),
        vec3(0.35458, 0.90834, 0.13383),
        vec3(0.04823, 0.01566, 0.83777)
    );
    // 近似表示：
    // ODT 饱和度调整
    // -> XYZ
    // -> D60 到 D65 白点适配
    // -> Linear sRGB / Rec.709

    const mat3 acesOutputMat = mat3(
        vec3( 1.60475, -0.10208, -0.00327),
        vec3(-0.53108,  1.10813, -0.07276),
        vec3(-0.07367, -0.00605,  1.07602)
    );

    color = max(color, vec3(0.0));
	color = acesInputMat * color;
    color = rrtAndOdtFit(color);
    color = acesOutputMat * color;

    return clamp(color, 0.0, 1.0);
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
	vec3 CN ;
	vec3 CR ;

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
		CN = normalize((vec4(NORMAL,0)*VIEW_MATRIX).rgb);
		CR = normalize(reflect(-V, CN));
		coatingFresnel = approximateCoatingEnvironmentFresnel(
			0.04,
			saturate((dot(CN, V))),
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

	vec3 finalColor =( diffuseAmbient + baseSpecularAmbient)*ao;

	if (useClearcoat) {

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

	finalColor *= exp2(uExposureEV);
	finalColor = acesFitted(finalColor);
	ALBEDO = (finalColor);
	ALPHA = 0.5;
}


