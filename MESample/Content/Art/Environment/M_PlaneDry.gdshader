shader_type spatial;
render_mode unshaded, world_vertex_coords;

// ==========================================
// 材质参数 (Uniforms)
// ==========================================

group_uniforms PointLights;
uniform vec3 PointLight1_WorldPos = vec3(5.0, 2.0, 0.0);
uniform vec3 PointLight1_Color : source_color = vec3(1.0, 0.8, 0.6);
uniform float PointLight1_Intensity = 15.0;

group_uniforms Ground;
uniform sampler2D BaseColor_Tex : source_color;
uniform float BaseColor_UV = 1.0;
uniform float BaseRough : hint_range(0.0, 1.0, 0.01) = 0.8;

group_uniforms Normal_Settings;
// 添加了 hint_normal 提示，避免法线贴图被sRGB压缩
uniform sampler2D Normal_Tex : hint_normal;
uniform float NormalIntensity : hint_range(0.0, 5.0, 0.01) = 1.0;
uniform float NormalUV = 1.0;
uniform bool Invert_Normal_Y = true;
uniform bool Flip_Binormal = false;

group_uniforms Global_Mask;
uniform vec3 Global_Mask_Color : source_color = vec3(0.0, 0.0, 0.0);
uniform float Global_Mask_Radius : hint_range(0.0, 0.5, 0.001) = 0.5;
uniform float Global_Mask_Softness : hint_range(0.001, 1.0, 0.001) = 0.2;

// ==========================================
// 顶点与公共变量 (Varyings & Core)
// ==========================================

varying vec3 V;
varying vec3 WorldPos;

// 将世界空间下的 TBN 数据通过 varying 传递
varying vec3 v_N_world;
varying vec3 v_T_world;
varying vec3 v_B_world;

void vertex() {
    V = normalize(CAMERA_POSITION_WORLD - VERTEX);
    WorldPos = VERTEX;
    
    // 在顶点着色器完成法线相关坐标系的转换
    v_N_world = NORMAL;
    v_T_world = TANGENT;
    v_B_world = BINORMAL;
}

// ==========================================
// 光照模型 (Lighting Models)
// ==========================================

vec3 calc_point_light_world(
    vec3 light_pos, vec3 light_color, float intensity, vec3 world_pos,
    vec3 N, vec3 V_dir, vec3 albedo, float roughness, vec3 f0
) {
    vec3 light_dir = light_pos - world_pos;
    float dist_sq = dot(light_dir, light_dir);
    float dist = sqrt(dist_sq);
    vec3 L = light_dir / (dist + 0.0001);
    float attenuation = 1.0 / (dist_sq + 1.0);

    vec3 light_term = light_color * (intensity * attenuation);

    // 使用 max 替换多余的截断
    float NdotL = max(dot(N, L), 0.0);
    vec3 diffuse = NdotL * light_term * albedo;

    vec3 H = normalize(V_dir + L);
    float NdotH = max(dot(N, H), 0.0);
    float HdotV = max(dot(H, V_dir), 0.0);

    float alpha = roughness * roughness;
    float alpha2 = max(alpha * alpha, 0.0001);
    float denom = (NdotH * NdotH * (alpha2 - 1.0) + 1.0);
    float D = alpha2 / (PI * denom * denom);

    // 展开 pow 函数提升效率
    float vH = 1.0 - HdotV;
    float vH2 = vH * vH;
    vec3 F = f0 + (1.0 - f0) * (vH2 * vH2 * vH);
    
    vec3 specular = (D * F * 0.25 * NdotL) * light_term;

    return diffuse + specular;
}

// ==========================================
// 片元着色器 (Fragment Pipeline)
// ==========================================

void fragment() {
    // ------------------------------------------
    // 1. 全局遮罩 (Global Mask)
    // ------------------------------------------
    float dist = distance(UV, vec2(0.5));
    float global_mask = 1.0 - smoothstep(
        Global_Mask_Radius - Global_Mask_Softness,
        Global_Mask_Radius,
        dist
    );

    // ------------------------------------------
    // 2. 法线与切线空间 (TBN & Normals)
    // ------------------------------------------
    // 直接使用归一化后的 Varying 变量，省去每像素的矩阵运算
    vec3 Nn = normalize(v_N_world);
    vec3 Tn = normalize(v_T_world);
    vec3 Bn = normalize(v_B_world);

    Bn = mix(Bn, -Bn, float(Flip_Binormal));

    mat3 TBN = mat3(Tn, Bn, Nn);

    vec3 map_n = texture(Normal_Tex, UV * NormalUV).rgb * 2.0 - 1.0;
    
    map_n.g = mix(map_n.g, -map_n.g, float(Invert_Normal_Y));

    map_n.xy *= NormalIntensity;
    map_n.z = sqrt(max(1.0 - dot(map_n.xy, map_n.xy), 0.0));

    // 直接使用地面法线，不再与积水平面法线进行混合
    vec3 N = normalize(TBN * map_n);

    // ------------------------------------------
    // 3. PBR 材质属性 (Albedo, Roughness, F0)
    // ------------------------------------------
    vec3 albedo = texture(BaseColor_Tex, UV * BaseColor_UV).rgb;
    float roughness = BaseRough;
    vec3 f0 = vec3(0.04); // 干燥非金属表面的默认基础反射率

    // ------------------------------------------
    // 4. 光照合成与输出 (Lighting & Output)
    // ------------------------------------------
    vec3 total_lighting = calc_point_light_world(
        PointLight1_WorldPos, PointLight1_Color, PointLight1_Intensity,
        WorldPos, N, V, albedo, roughness, f0
    );

    ALBEDO = mix(Global_Mask_Color, total_lighting, global_mask);
    
    
}
