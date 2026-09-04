shader_type spatial;

// 渲染模式：无内置光照、使用世界空间顶点坐标、强制深度写入(适用于玻璃)
render_mode unshaded, world_vertex_coords, depth_draw_always;

// ==========================================
// Uniforms: 全局参数配置 (保持原样无损兼容)
// ==========================================

group_uniforms Env;
uniform samplerCube SkyLihgt;       
uniform samplerCube IrradianceMap;  
uniform sampler2D LUT;              
uniform float env_rotate = 2.24;    

group_uniforms Base_Color;
uniform sampler2D Basecolor_Tex;    
uniform float Basecolor_UV = 1.0;   
uniform vec3 BaseColorCenter : source_color = vec3(1.0); 
uniform vec3 BaseColorEdge : source_color = vec3(0.75);  
uniform float Exposure : hint_range(0.0, 1.0, 0.01) = 0.7; 
uniform float BaseColor_Fresnel_Exponent = 2.0;          
uniform float BaseColor_Fresnel_Falloff = 0.04;          
uniform float BaseColor_Fresnel_Power = 1.0;             

group_uniforms Attribute;
uniform float opacity = 0.85;                                  
uniform float Metallic : hint_range(0.0, 1.0, 0.01) = 0.0;     
uniform float roughness_Min : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float roughness_Max : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float diffuseIntensity = 1.0;                          
uniform float specularIntensity = 1.0;                         

uniform sampler2D ORS_Tex;          
uniform bool useN = false;          
uniform sampler2D Normal_Tex;       
uniform float normalIntensity : hint_range(0.0, 1.0, 0.01) = 0.5; 
uniform float NormalUV = 1.0;       
uniform float ao_Min : hint_range(0.0, 1.0, 0.01) = 0.0;       
uniform float ao_Max : hint_range(0.0, 1.0, 0.01) = 1.0;       
uniform float shadow_Min : hint_range(0.0, 1.0, 0.01) = 0.0;   
uniform float shadow_Max : hint_range(0.0, 1.0, 0.01) = 1.0;   

// ==========================================
// Varyings: 顶点向片元传递的数据
// ==========================================

varying vec3 V;       
varying vec3 World_N; 
varying vec3 World_T; 
varying vec3 World_B; 

const vec3 AP1_RGB2Y = vec3(0.2722287, 0.6740818, 0.0536895);

// ==========================================
// 数学与核心管线函数
// ==========================================

vec3 ACESFilm(vec3 LinearColor) {
    vec3 C = max(LinearColor, vec3(0.0));
    C = mix(vec3(dot(C, AP1_RGB2Y)), C, 0.96); 
    vec3 ToneColor = (C * (2.51 * C + 0.03)) / (C * (2.43 * C + 0.59) + 0.14);
    return clamp(mix(vec3(dot(ToneColor, AP1_RGB2Y)), ToneColor, 0.93), 0.0, 1.0);
}

vec2 EnvBRDFApprox_UE4(float Roughness, float NoV) {
    const vec4 c0 = vec4(-1.0, -0.0275, -0.572, 0.022);
    const vec4 c1 = vec4(1.0, 0.0425, 1.04, -0.04);
    vec4 r = Roughness * c0 + c1;
    float a004 = min(r.x * r.x, exp2(-9.28 * NoV)) * r.x + r.y;
    return vec2(-1.04, 1.04) * a004 + r.zw;
}

vec3 rotateAroundY(vec3 v, float cosTheta, float sinTheta) {
    return vec3(
        v.x * cosTheta - v.z * sinTheta,
        v.y,
        v.x * sinTheta + v.z * cosTheta
    );
}

// ==========================================
// 顶点着色器
// ==========================================
void vertex() {
    V = CAMERA_POSITION_WORLD - VERTEX;
    World_N = NORMAL;
    
    if (useN) {
        World_T = TANGENT;
        World_B = BINORMAL;
    }
}

// ==========================================
// 片元着色器
// ==========================================
void fragment() {
    // [优化] 直接计算纯 Uniform 环境变量，触发 SPIR-V 常量折叠
    float c_env = cos(env_rotate);
    float s_env = sin(env_rotate);
    
    // [优化] 预组合不变的材质因子，提取单标量指令
    vec3 F0 = mix(vec3(0.04), BaseColorCenter, Metallic);
    float uniform_kd_factor = (1.0 - Metallic) * diffuseIntensity;

    vec3 V_norm = normalize(V); 
    vec3 GeomN = normalize(World_N);
    vec3 N = GeomN;
    
    // 解析法线贴图及 TBN 矩阵重构
    if (useN) {
        vec3 map_n = texture(Normal_Tex, UV * NormalUV).rgb * 2.0 - 1.0;
        map_n.g = -map_n.g; 
        map_n = mix(vec3(0.0, 0.0, 1.0), map_n, normalIntensity);
        mat3 TBN = mat3(normalize(World_T), normalize(World_B), GeomN);
        N = normalize(TBN * map_n);
    }

    float ndotv = clamp(dot(N, V_norm), 0.0, 1.0);

    // Schlick 菲涅尔效应近似
    float f_pow = 1.0 - ndotv;
    float f2 = f_pow * f_pow;
    float Frenel = (f2 * f2 * f_pow) * 0.96 + 0.04;

    // [优化] 直接使用预组合因子，计算最终漫反射强度
    float kd = uniform_kd_factor * (1.0 - Frenel);

    vec3 BaseColor = mix(BaseColorCenter, BaseColorEdge, BaseColor_Fresnel_Power * Frenel) * texture(Basecolor_Tex, UV * Basecolor_UV).rgb;

    // [优化] 将 Min/Max 区间提前打包为 vec3，触发硬件 SIMD 单指令混合
    vec3 ors_min_vec = vec3(ao_Min, roughness_Min, shadow_Min);
    vec3 ors_max_vec = vec3(ao_Max, roughness_Max, shadow_Max);
    vec3 mapped_ors = mix(ors_min_vec, ors_max_vec, texture(ORS_Tex, UV * Basecolor_UV).rgb);
    
    float ao = mapped_ors.x;
    float roughness = mapped_ors.y;
    float shadow = mapped_ors.z;

    // --- 漫反射环境光照 ---
    vec3 rot_N = rotateAroundY(N, -c_env, -s_env);
    vec3 irradiance = textureLod(IrradianceMap, rot_N, 0.0).rgb;
    vec3 diffuse = irradiance * BaseColor * kd;

    // --- 镜面高光环境反射 ---
    // (注：严格保留原代码中 reflect(V_norm, N) 及 Swizzle 的数学特征以保证表现一致)
    vec3 R = normalize(reflect(V_norm, N));
    vec3 rot_R = rotateAroundY(vec3(R.x, -R.y, R.z), c_env, s_env);
    vec3 prefilteredColor = textureLod(SkyLihgt, rot_R, roughness * 4.0).rgb;

    vec2 scale_bias = EnvBRDFApprox_UE4(roughness, ndotv);
    vec3 specular = prefilteredColor * (F0 * scale_bias.x + scale_bias.y) * specularIntensity;

    // --- 最终输出与后处理 ---
    vec3 final = diffuse + specular;
    ALBEDO = ACESFilm(final * Exposure) * (shadow * ao);
    ALPHA = opacity; 
}
