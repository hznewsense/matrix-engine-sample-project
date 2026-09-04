shader_type spatial;
render_mode unshaded, world_vertex_coords, cull_disabled;

#define S(a) clamp(a, 0.0, 1.0)

// ==========================================
// 材质参数 (Uniforms)
// ==========================================

group_uniforms PointLights;
uniform vec3 PointLight1_Pos = vec3(5.0, 2.0, 0.0);                  // 点光源世界坐标 (笛卡尔坐标)
uniform vec3 PointLight1_Color : source_color = vec3(1.0, 0.8, 0.6); // 点光源颜色
uniform float PointLight1_Intensity = 15.0;                          // 点光源强度

group_uniforms Ground;
uniform sampler2D BaseColor_Tex : source_color;                      // 地面基础颜色贴图
uniform float BaseColor_UV = 1.0;                                    // 基础颜色贴图 UV 缩放
uniform float BaseRough : hint_range(0.0, 1.0, 0.01) = 0.8;          // 基础粗糙度
uniform float Porosity : hint_range(0.0, 1.0, 0.1) = 0.8;            // 多孔性 (控制潮湿时地面变暗的程度)
uniform float Ground_Fresnel_Intensity : hint_range(0.0, 1.0, 0.01) = 0.15; // 干燥地面的菲涅尔反射强度
uniform vec3 Ground_Fresnel_Color : source_color = vec3(0.03, 0.05, 0.07);  // 地面环境天光反射颜色 (模拟暗部微弱天光)

group_uniforms Normal_Settings;
uniform sampler2D Normal_Tex;                                        // 法线贴图
uniform float NormalIntensity : hint_range(0.0, 5.0, 0.01) = 1.0;    // 法线凹凸强度
uniform float NormalUV = 1.0;                                        // 法线贴图 UV 缩放
uniform bool DirectX_Normal_Format = true;                           // 是否适配 DirectX 法线格式 (勾选为 Y-，取消为 OpenGL 的 Y+)
uniform bool Flip_Binormal = false;                                  // 是否翻转副切线

group_uniforms Water_Mask;
uniform sampler2D Mask_Tex;                                          // 水坑遮罩贴图
uniform float Mask_UV = 1.0;                                         // 遮罩贴图 UV 缩放
uniform float Water_Level : hint_range(0.0, 1.0, 0.01) = 0.5;        // 整体水位高度
uniform float Water_Softness : hint_range(0.001, 1.0, 0.001) = 0.1;  // 水坑边缘柔和度/过渡范围
uniform float Water_Int : hint_range(0.0, 1.0, 0.01) = 1.0;          // 积水区域的透明度/不透明度强度

group_uniforms Global_Mask;
uniform vec3 Global_Mask_Color : source_color = vec3(0.0, 0.0, 0.0); // 全局边缘遮罩颜色
uniform float Global_Mask_Radius : hint_range(0.0, 0.5, 0.001) = 0.5;    // 全局边缘遮罩半径
uniform float Global_Mask_Softness : hint_range(0.001, 1.0, 0.001) = 0.2;// 全局边缘遮罩柔和度

group_uniforms Switch;
uniform bool AIchange = false;                                       // AI 模式切换开关
uniform vec3 AI_BaseColor : source_color = vec3(0.5, 0.5, 0.5);      // AI 模式下的基础颜色
uniform vec3 AI_GlobalMaskColor : source_color = vec3(0.0, 0.0, 0.0);// AI 模式下的全局遮罩颜色
uniform float AI_GlobalMask_Radius : hint_range(0.0, 0.5, 0.001) = 0.5;      // AI 模式遮罩半径
uniform float AI_GlobalMask_Softness : hint_range(0.001, 1.0, 0.001) = 0.2;  // AI 模式遮罩柔和度
uniform float AI_BaseAlpha : hint_range(0.0, 1.0, 0.01) = 1.0;

// ==========================================
// 顶点与公共变量 (Varyings)
// ==========================================

varying vec3 V;           // 视线向量 (由顶点指向相机)
varying vec3 WorldPos;    // 世界空间顶点坐标
varying vec3 WorldT;      // 世界空间切线
varying vec3 WorldB;      // 世界空间副切线
varying vec3 WorldN;      // 世界空间法线

void vertex() {
    V = normalize(CAMERA_POSITION_WORLD - VERTEX);
    WorldPos = VERTEX; 
    
    // 直接获取世界空间下的 TBN 向量 (依赖 world_vertex_coords 模式)
    WorldT = TANGENT;
    WorldB = BINORMAL;
    WorldN = NORMAL;
}

// ==========================================
// 光照模型 (基于物理的 BRDF 近似)
// ==========================================

vec3 calc_point_light_cartesian(
    vec3 light_pos, vec3 light_color, float intensity, vec3 world_pos, 
    vec3 N, vec3 V_dir, vec3 albedo, float roughness, vec3 f0, 
    float fresnel_intensity 
) {
    vec3 light_dir = light_pos - world_pos;
    float dist_sq = dot(light_dir, light_dir);
    
    // 距离衰减计算 (使用 inversesqrt 加速)
    float inv_dist = inversesqrt(max(dist_sq, 0.0001));
    vec3 L = light_dir * inv_dist; 
    float attenuation = 1.0 / (dist_sq + 1.0); 
    
    // 漫反射项
    float NdotL = S(dot(N, L));
    vec3 diffuse = NdotL * light_color * intensity * attenuation * albedo;
    
    // 高光项准备参数
    vec3 H = normalize(V_dir + L); 
    float NdotH = S(dot(N, H));
    float HdotV = S(dot(H, V_dir));
    
    // 法线分布函数 (NDF - GGX)
    float alpha = roughness * roughness;
    float alpha2 = max(alpha * alpha, 0.0001);
    float denom = (NdotH * NdotH * (alpha2 - 1.0) + 1.0);
    float D = alpha2 / (PI * denom * denom);
    
    // 菲涅尔等式 (Schlick 近似展开)
    float hdv = 1.0 - HdotV;
    float hdv2 = hdv * hdv;
    float hdv5 = hdv2 * hdv2 * hdv;
    vec3 F = f0 + (1.0 - f0) * hdv5 * fresnel_intensity;
    
    // 几何遮蔽项省略后的简化微面元高光
    vec3 specular = (D * F * 0.25) * light_color * intensity * attenuation * NdotL;
    
    return diffuse + specular;
}

// ==========================================
// 片元着色器 (Fragment)
// ==========================================

void fragment() {
    
    // 计算 UV 到中心的距离，用于生成全局边缘遮罩
    float dist_to_center = distance(UV, vec2(0.5)); 

    if (AIchange) {
        // ------------------------------------------
        // AI 模式渲染逻辑
        // ------------------------------------------
        float ai_global_mask = 1.0 - smoothstep(
            AI_GlobalMask_Radius - AI_GlobalMask_Softness,
            AI_GlobalMask_Radius,
            dist_to_center
        );

        ALBEDO = mix(AI_GlobalMaskColor, AI_BaseColor, ai_global_mask);
        ALPHA = AI_BaseAlpha;

    } else {
        // ------------------------------------------
        // 标准物理模式渲染逻辑
        // ------------------------------------------
        float global_mask = 1.0 - smoothstep(
            Global_Mask_Radius - Global_Mask_Softness,
            Global_Mask_Radius,
            dist_to_center
        );

        // 1. 水坑遮罩计算
        float raw_mask = S(texture(Mask_Tex, UV * Mask_UV).r); 
        float threshold = 1.0 - Water_Level; 
        float half_soft = Water_Softness * 0.5;
        
        float Wetness = smoothstep(threshold - half_soft, threshold + half_soft, raw_mask);
        Wetness = S(Wetness * Water_Int);
        float puddle_mask = smoothstep(0.5, 1.0, Wetness);

        // 2. TBN 矩阵与法线贴图解析
        vec3 T_world = WorldT;
        vec3 B_world = Flip_Binormal ? -WorldB : WorldB;
        vec3 N_world = WorldN;
        mat3 TBN = mat3(normalize(T_world), normalize(B_world), normalize(N_world));
        
        vec3 map_n = texture(Normal_Tex, UV * NormalUV).rgb * 2.0 - 1.0;
        
        // 适配 DirectX 法线格式 (G通道翻转)
        if (DirectX_Normal_Format) { 
            map_n.g = -map_n.g; 
        }
        
        map_n.xy *= NormalIntensity;
        map_n.z = sqrt(max(1.0 - dot(map_n.xy, map_n.xy), 0.0)); 
        
        // 混合原始法线与水坑区域的平滑法线
        vec3 GroundN = normalize(TBN * map_n); 
        vec3 N = normalize(mix(GroundN, normalize(N_world), puddle_mask));
        
        // 3. 材质基础属性获取与潮湿状态混合
        float NdotV = S(dot(N, V));
        vec3 base_color_val = texture(BaseColor_Tex, UV * BaseColor_UV).rgb;
        vec3 wetAlbedo = mix(base_color_val, base_color_val * base_color_val, Porosity * Wetness);
        
        const float WATER_ROUGHNESS = 0.02;         
        const float WATER_F0 = 0.02;   
        
        float wetRoughness = mix(BaseRough, WATER_ROUGHNESS, puddle_mask);
        
        // F0 (基础反射率) 混合
        vec3 groundF0 = mix(vec3(0.04), vec3(0.02), Porosity * Wetness);
        vec3 baseF0 = mix(groundF0, vec3(WATER_F0), puddle_mask);
        
        // 视线掠射角菲涅尔计算 (用于透明度衰减与环境光)
        float ndv = 1.0 - NdotV;
        float ndv2 = ndv * ndv;
        float ndv5 = ndv2 * ndv2 * ndv;
        float fresnel = WATER_F0 + (1.0 - WATER_F0) * ndv5;
        float transmittance = 1.0 - fresnel;
        
        vec3 total_lighting = vec3(0.0);
        
        // 4. 点光源计算
        // 动态计算当前像素的菲涅尔强度因子 (水坑满反射，干燥地面使用预设强度)
        float current_fresnel_int = mix(Ground_Fresnel_Intensity, 1.0, puddle_mask);
        
        total_lighting += calc_point_light_cartesian(
            PointLight1_Pos,
            PointLight1_Color,
            PointLight1_Intensity, 
            WorldPos,
            N,
            V,
            wetAlbedo,
            wetRoughness,
            baseF0,
            current_fresnel_int
        );

        // 5. 全局环境天光菲涅尔
        // 仅在干燥地面添加环境光反射，赋予无光照区域微弱的立体感
        vec3 ambient_fresnel = Ground_Fresnel_Color * ndv5 * Ground_Fresnel_Intensity * (1.0 - puddle_mask);
        total_lighting += ambient_fresnel;

        // 6. 最终输出计算
        float surface_alpha = mix(1.0, transmittance, Wetness);
        
        ALBEDO = mix(Global_Mask_Color, total_lighting, global_mask); 
        ALPHA = mix(1.0, surface_alpha, global_mask);
    }
}
