shader_type spatial;
render_mode unshaded,world_vertex_coords,cull_disabled;
#define S(a) clamp(a,0,1)

group_uniforms Env;
uniform sampler2D SkyLihgt;
uniform sampler2D IrradianceMap;
uniform sampler2D LUT;
uniform float env_rotate = 0.0;
uniform float env_saturate:hint_range(-1.0, 1.0, 0.01) = 0.0;

group_uniforms Base_Color;
uniform bool use_basecolor_tex = true;
uniform sampler2D Basecolor_Tex;
uniform float Basecolor_UV = 1.0;
uniform vec3 BaseColorCenter:source_color = vec3(1);
uniform vec3 BaseColorEdge:source_color = vec3(0.75);
uniform float BaseColor_Fresnel_Exponent = 2.0;
uniform float BaseColor_Fresnel_Falloff = 0.04;
uniform float BaseColor_Fresnel_Power = 1.0;


group_uniforms Attribute;
uniform float Metallic:hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float roughness_Min:hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float roughness_Max:hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float diffuseIntensity= 1.0;
uniform float specularIntensity= 1.0;
uniform sampler2D ORS_Tex; // AO / Roughness / Shadow Tex
uniform bool useN = false;
uniform sampler2D Normal_Tex;
uniform float normalIntensity:hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float NormalUV = 1.0;
uniform float ao_Min:hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float ao_Max:hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float shadow_Min:hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float shadow_Max:hint_range(0.0, 1.0, 0.01) =1.0;
uniform float clearcoat_Intensity = 1.0;
uniform float C_Roughness:hint_range(0.0, 1.0, 0.01) = 0.0;

group_uniforms Film;
uniform float slope = 0.88;
uniform float toe = 0.55;
uniform float shoulder = 0.26;
uniform float blackclip = 0.0;
uniform float whiteclip = 0.04;


varying vec3 V ;
varying vec3 Vt ;
varying vec3 VC;
void vertex() {
	// Called for every vertex the material is visible on.
	V = normalize(CAMERA_POSITION_WORLD-VERTEX);
	Vt = VERTEX;
	VC = COLOR.rgb;
}

vec3 adjustSaturation(vec3 rgb, float s) {
    // 将RGB转换为HSV
	float r = rgb.r;
	float g = rgb.g;
	float b = rgb.b;
	b = b+(b-(r+g)/2.0)*s;
	g = g+(g-(b+r)/2.0)*s;
	r = r+(r-(b+g)/2.0)*s;
    // 将HSV转换回RGB
    return vec3(r,g,b);
}

vec2 DirectionToLatLongUV(vec3 dir)
{
    dir = normalize(dir);

    float u = atan(dir.z, dir.x) / (2.0 * PI) + 0.5;
    float v = asin(clamp(dir.y, -1.0, 1.0)) / PI + 0.5;
	v = 1.0 - v;
    return vec2(u, v);
}
vec3 SampleHDRI(sampler2D Env,vec3 worldDir,float mip)
{
    vec2 uv = DirectionToLatLongUV(worldDir);
	vec3 t = textureLod(Env, uv,mip).rgb;
    return adjustSaturation(t,env_saturate);
}

vec3 ApplyLUT(sampler2D lutTex, vec3 color01, float intensity)
{
    color01 = clamp(color01, 0.0, 1.0);

    const float N = 16.0;
    const float maxIndex = N - 1.0;

    vec3 scaled = color01 * maxIndex;

    float z0 = floor(scaled.b);
    float z1 = min(z0 + 1.0, maxIndex);
    float zf = scaled.b - z0;

    // width = 256 = 16*16, height = 16
    vec2 uv0 = vec2((scaled.r + 0.5 + z0 * N) / (N * N),
                    (scaled.g + 0.5) / N);
    vec2 uv1 = vec2((scaled.r + 0.5 + z1 * N) / (N * N),
                    uv0.y);

    vec3 c0 = texture(lutTex, uv0).rgb;
    vec3 c1 = texture(lutTex, uv1).rgb;

    vec3 lutColor = mix(c0, c1, zf);
    return mix(color01, lutColor, clamp(intensity, 0.0, 1.0));
}



vec3 rotateVectorAroundAxis(vec3 v, vec3 axis, float theta) {
    axis = normalize(axis);

    // 计算旋转矩阵
    float cosTheta = cos(theta);
    float sinTheta = sin(theta);
    vec3 k = axis;

    // 旋转矩阵的元素
    float r11 = cosTheta + k.x * k.x * (1.0 - cosTheta);
    float r12 = k.x * k.y * (1.0 - cosTheta) - k.z * sinTheta;
    float r13 = k.x * k.z * (1.0 - cosTheta) + k.y * sinTheta;

    float r21 = k.y * k.x * (1.0 - cosTheta) + k.z * sinTheta;
    float r22 = cosTheta + k.y * k.y * (1.0 - cosTheta);
    float r23 = k.y * k.z * (1.0 - cosTheta) - k.x * sinTheta;

    float r31 = k.z * k.x * (1.0 - cosTheta) - k.y * sinTheta;
    float r32 = k.z * k.y * (1.0 - cosTheta) + k.x * sinTheta;
    float r33 = cosTheta + k.z * k.z * (1.0 - cosTheta);

    // 旋转矩阵
    mat3 rotationMatrix = mat3(
       vec3( r11, r12, r13),
       vec3( r21, r22, r23),
       vec3( r31, r32, r33)
		);

    return rotationMatrix * v;
}

float log10(float x)
{
    return log(x) / log(10.0); 
}
vec3 Vlog10(vec3 x)
{
    return log(x) / log(10.0); 
}

float saturate(float x) { return clamp(x, 0.0, 1.0); }
vec3  Vsaturate(vec3  x) { return clamp(x, vec3(0.0), vec3(1.0)); }

float lerp(float A, float B, float T) { return A + (B - A) * T; }
vec3  Vlerp(vec3  A, vec3  B, float T) { return A + (B - A) * T; }

vec3 selectVec3(bvec3 cond, vec3 A, vec3 B) { return vec3(cond.x ? A.x : B.x, cond.y ? A.y : B.y, cond.z ? A.z : B.z); }
const vec3 AP1_RGB2Y = vec3(0.2722287168, 0.6740817658, 0.0536895174);

// FilmSlope    : 0.0~1.0+
// FilmToe      : 0.0~1.0
// FilmShoulder : 0.0~1.0
// FilmBlackClip: 0.0~1.0
// FilmWhiteClip: 0.0~1.0
vec3 FilmToneMap_Simplified(
    vec3 LinearColor,
    float FilmSlope,
    float FilmToe,
    float FilmShoulder,
    float FilmBlackClip,
    float FilmWhiteClip
){
    vec3 C = max(LinearColor, vec3(0.0));

    // 1) Pre desaturate
    float Y = dot(C, AP1_RGB2Y);
    C= Vlerp(vec3(Y), C, 0.96);

    // 2) 计算 Toe / Shoulder 的缩放
    float ToeScale      = 1.0 + FilmBlackClip - FilmToe;
    float ShoulderScale = 1.0 + FilmWhiteClip - FilmShoulder;

    // 3) 中灰匹配
    const float InMatch  = 0.18;
    const float OutMatch = 0.18;

    // 4) 解 ToeMatch（让 InMatch 映射到 OutMatch）
    float ToeMatch;
    if (FilmToe > 0.8) {
        ToeMatch = (1.0 - FilmToe - OutMatch) / FilmSlope + log10(InMatch);
    } else {
        float bt = (OutMatch + FilmBlackClip) / ToeScale - 1.0;
        bt = clamp(bt, -0.999, 0.999);
        ToeMatch = log10(InMatch) - 0.5 * log((1.0 + bt) / (1.0 - bt)) * (ToeScale / FilmSlope);
    }

    float StraightMatch = (1.0 - FilmToe) / FilmSlope - ToeMatch;
    float ShoulderMatch = FilmShoulder / FilmSlope - StraightMatch;

    // 5) Log 域处理（避免 log10(0)）
    vec3 LogColor = Vlog10(max(C, vec3(1e-6)));

    vec3 StraightColor = FilmSlope * (LogColor + vec3(StraightMatch));

    vec3 ToeColor = vec3(-FilmBlackClip) +
        (2.0 * ToeScale) / (1.0 + exp(((-2.0 * FilmSlope) / ToeScale) * (LogColor - vec3(ToeMatch))));

    vec3 ShoulderColor = vec3(1.0 + FilmWhiteClip) -
        (2.0 * ShoulderScale) / (1.0 + exp((( 2.0 * FilmSlope) / ShoulderScale) * (LogColor - vec3(ShoulderMatch))));

    // 6) 分段选择：Toe / Straight / Shoulder
    bvec3 inToe      = lessThan(LogColor, vec3(ToeMatch));
    bvec3 inShoulder = greaterThan(LogColor, vec3(ShoulderMatch));

    vec3 mixed = StraightColor;
    mixed = selectVec3(inToe, ToeColor, mixed);
    mixed = selectVec3(inShoulder, ShoulderColor, mixed);

    // 7)平滑过渡权重 t（Hermite）
    vec3 t = Vsaturate((LogColor - vec3(ToeMatch)) / (vec3(ShoulderMatch - ToeMatch)));
    if (ShoulderMatch < ToeMatch) t = vec3(1.0) - t;

    t = (3.0 - 2.0 * t) * t * t;

    vec3 ToneColor = mix(ToeColor, ShoulderColor, t);
    // 对 Toe/Shoulder 外的区域，还是用分段 mixed
    ToneColor = selectVec3(inToe, ToeColor, ToneColor);
    ToneColor = selectVec3(inShoulder, ShoulderColor, ToneColor);

    // 8) Post desaturate
    float TY = dot(ToneColor, AP1_RGB2Y);
    ToneColor = Vlerp(vec3(TY), ToneColor, 0.93);

    return max(ToneColor, vec3(0.0));
}

vec2 EnvBRDFApprox(float Roughness, float NoV )
{
    // [ Lazarov 2013, "Getting More Physical in Call of Duty: Black Ops II" ]
    // Adaptation to fit our G term.
    const vec4 c0 = vec4(-1.0, -0.0275, -0.572, 0.022);
    const vec4 c1 = vec4(1.0, 0.0425, 1.04, -0.04);
    vec4 r = Roughness * c0 + c1;
    float a004 = min( r.x * r.x, exp2( -9.28 * NoV ) ) * r.x + r.y;
    vec2 AB = vec2( -1.04, 1.04 ) * a004 + r.zw;
    return AB;
}

void fragment() {
	vec3 N = normalize((vec4(NORMAL,0)*VIEW_MATRIX).rgb);

	vec3 F0 = mix(vec3(0.04),BaseColorCenter,Metallic);
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

    float Frenel = pow(1.0 - S(dot(V, N)), 5.0) * (1.0 - 0.04) + 0.04;
    vec3 R = normalize(reflect(V, N));
	vec3 ks = vec3(Frenel);
	vec3 kd = (1.0-Metallic)*(vec3(1)-ks);
	vec3 tex_base = texture(Basecolor_Tex, UV * Basecolor_UV).rgb;

	vec3  CenterColor = BaseColorCenter;
	vec3  EdgeColor   = BaseColorEdge;

	// 原本那套（Fresnel边缘色）
	vec3 fresnel_color = mix(
	    CenterColor,
	    mix(CenterColor, EdgeColor, BaseColor_Fresnel_Power),
	    Frenel
	);

	// 🔥 开关控制
		vec3 BaseColor = use_basecolor_tex
		    ? tex_base
		    : fresnel_color;


	vec3 ORS = texture(ORS_Tex, UV).rgb;
	float ao = mix(ao_Min,ao_Max,ORS.r) ;
	float roughness = mix(roughness_Min,roughness_Max,texture(ORS_Tex, UV*Basecolor_UV).g);
	float shadow = mix(shadow_Min,shadow_Max,ORS.b) ;

	vec3 irradiance = SampleHDRI(IrradianceMap,rotateVectorAroundAxis(N, vec3(0,1,0), env_rotate+PI),0).rgb;
	vec3 diffuse = kd*irradiance*BaseColor*diffuseIntensity;

	vec3 prefilteredColor = SampleHDRI(SkyLihgt,rotateVectorAroundAxis(R * vec3(1,-1,1), vec3(0,1,0), env_rotate),roughness * 4.0).rgb;
	vec2 scale_bias = EnvBRDFApprox(roughness,dot(N,V));
	vec3 specular = prefilteredColor*(F0*scale_bias.x+scale_bias.y)*specularIntensity;
	vec3 ambient = diffuse+specular;

	//clearcoat
	vec3 CN = normalize((vec4(NORMAL,0)*VIEW_MATRIX).rgb);
	vec3 CR = normalize(reflect(V, CN));
	vec3 C_prefilteredColor = SampleHDRI(SkyLihgt,rotateVectorAroundAxis(CR * vec3(1,-1,1), vec3(0,1,0), env_rotate),C_Roughness).rgb;
	vec2 C_scale_bias = EnvBRDFApprox(0.01,dot(CN,V));
	vec3 C_specular = C_prefilteredColor*(F0*C_scale_bias.x+C_scale_bias.y)*clearcoat_Intensity;

	vec3 final = ambient+C_specular;
    ALBEDO = FilmToneMap_Simplified(final, slope, toe, shoulder, blackclip, whiteclip);
    ALBEDO = ALBEDO * shadow * ao;

}

//void light() {
	// Called for every pixel for every light affecting the material.
	// Uncomment to replace the default light processing function with this one.
//}
