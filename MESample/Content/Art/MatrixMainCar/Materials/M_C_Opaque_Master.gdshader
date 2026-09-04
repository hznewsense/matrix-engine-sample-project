	/// === 优化配置文件: M_C_Opaque_Master.gdshader ===

shader_type spatial;

// 渲染模式：无内置光照(完全自定义)、使用世界空间坐标、禁用背面剔除
render_mode unshaded, world_vertex_coords, cull_disabled;

// ==========================================
// Uniforms: 材质与环境参数配置
// ==========================================

group_uniforms Env; // --- 环境光与反射设置 ---
uniform samplerCube SkyLihgt;                                  // 天空盒环境贴图：用于计算高光反射 (拼写保留原样)
uniform samplerCube IrradianceMap;                             // 辐照度贴图：用于计算漫反射全局光照 (GI)
uniform float Irradiance_Saturation : hint_range(0.0, 2.0, 0.01) = 0.4; // IrradianceMap 饱和度：0=灰度，1=原始，2=增强
uniform sampler2D LUT;                                         // 颜色查找表：用于色彩映射与校正
uniform float env_rotate = 2.24;                               // 环境光旋转角度：控制环境贴图的水平旋转

group_uniforms Base_Color; // --- 基础颜色与菲涅尔设置 ---
uniform sampler2D Basecolor_Tex;                               // 基础颜色贴图
uniform float Basecolor_UV = 1.0;                              // 基础颜色贴图的 UV 缩放系数
uniform vec3 BaseColorCenter : source_color = vec3(1.0);       // 正视底色：视线垂直于表面时看到的颜色
uniform vec3 BaseColorEdge : source_color = vec3(0.75);        // 侧视底色：视线平行于表面(掠射角)时看到的颜色
uniform float Exposure : hint_range(0.0, 1.0, 0.01) = 0.7;     // 曝光度：控制最终输出颜色的整体明暗
uniform float BaseColor_Fresnel_Exponent = 2.0;                // 菲涅尔指数：控制正侧视颜色过渡的曲率/范围
uniform float BaseColor_Fresnel_Falloff = 0.04;                // 菲涅尔衰减：控制菲涅尔效果的边缘过渡平滑度
uniform float BaseColor_Fresnel_Power = 1.0;                   // 菲涅尔强度：正视与侧视颜色混合的整体权重乘数

group_uniforms Attribute; // --- 表面物理属性与纹理设置 ---
uniform float Metallic : hint_range(0.0, 1.0, 0.01) = 0.0;     // 金属度：0为非金属，1为纯金属
uniform float roughness_Min : hint_range(0.0, 1.0, 0.01) = 0.5;// 粗糙度下限：映射 ORS 贴图粗糙度的最小值
uniform float roughness_Max : hint_range(0.0, 1.0, 0.01) = 0.5;// 粗糙度上限：映射 ORS 贴图粗糙度的最大值
uniform float diffuseIntensity = 1.0;                          // 漫反射强度：控制表面接收环境漫反射的光量
uniform float specularIntensity = 1.0;                         // 高光反射强度：控制表面对环境反射贴图的反射强度

uniform sampler2D ORS_Tex;                                     // 综合属性贴图 (Occlusion, Roughness, Shadow)
uniform float ORS_UV = 1.0;                                    // 综合属性贴图的 UV 缩放系数
uniform float ao_Min : hint_range(0.0, 1.0, 0.01) = 0.0;       // AO下限：映射环境遮蔽(R通道)的最小值
uniform float ao_Max : hint_range(0.0, 1.0, 0.01) = 1.0;       // AO上限：映射环境遮蔽(R通道)的最大值
uniform float shadow_Min : hint_range(0.0, 1.0, 0.01) = 0.0;   // 阴影下限：映射阴影遮罩(B通道)的最小值
uniform float shadow_Max : hint_range(0.0, 1.0, 0.01) = 1.0;   // 阴影上限：映射阴影遮罩(B通道)的最大值

uniform bool useVertexColor = false;                           // 顶点颜色开关：是否将网格自带的顶点颜色与底色正片叠底
uniform bool useN = false;                                     // 法线开关：是否启用表面凹凸细节
uniform sampler2D Normal_Tex;                                  // 法线贴图：提供表面微观凹凸数据
uniform float normalIntensity : hint_range(0.0, 1.0, 0.01) = 0.5; // 法线强度：控制凹凸效果的深度
uniform float NormalUV = 1.0;                                  // 法线UV缩放：法线贴图的平铺密度

uniform bool useClearcoat = false;                             // 清漆层开关：是否在表层额外叠加一层高光反射
uniform float clearcoat_Intensity = 1.0;                       // 清漆层强度：控制最外层透明涂层的高光亮度

// ==========================================
// Varyings: 顶点与片元着色器间传递的数据
// ==========================================
varying vec3 V;       // 视线向量 (由顶点指向相机)
varying vec3 VC;      // 顶点颜色
varying vec3 World_N; // 世界空间法线向量
varying vec3 World_T; // 世界空间切线向量
varying vec3 World_B; // 世界空间副切线向量

const vec3 AP1_RGB2Y = vec3(0.2722287, 0.6740818, 0.0536895); // 亮度转换常量 (用于 ACES 色调映射)

// ==========================================
// 核心处理函数
// ==========================================

// 向量绕 Y 轴旋转 (避开矩阵中多余的0，此原生实现已是最优解)
vec3 rotateAroundY(vec3 v, float cosTheta, float sinTheta) {
    return vec3(
        v.x * cosTheta - v.z * sinTheta,
        v.y,
        v.x * sinTheta + v.z * cosTheta
    );
}

// 高性能 ACES 电影级色调映射拟合：防止高光过曝，色彩更自然
vec3 ACESFilm(vec3 LinearColor) {
    vec3 C = max(LinearColor, vec3(0.0));
    C = mix(vec3(dot(C, AP1_RGB2Y)), C, 0.96);
    vec3 ToneColor = (C * (2.51 * C + 0.03)) / (C * (2.43 * C + 0.59) + 0.14);
    return clamp(mix(vec3(dot(ToneColor, AP1_RGB2Y)), ToneColor, 0.93), 0.0, 1.0);
}

// UE4 移动端环境 BRDF 近似计算：利用多项式快速计算基于图像的光照反射
vec2 EnvBRDFApprox_UE4(float Roughness, float NoV) {
    const vec4 c0 = vec4(-1.0, -0.0275, -0.572, 0.022);
    const vec4 c1 = vec4(1.0, 0.0425, 1.04, -0.04);
    vec4 r = Roughness * c0 + c1;
    float a004 = min(r.x * r.x, exp2(-9.28 * NoV)) * r.x + r.y;
    return vec2(-1.04, 1.04) * a004 + r.zw;
}

// ==========================================
// 顶点着色器
// ==========================================
void vertex() {
    V = normalize(CAMERA_POSITION_WORLD - VERTEX);
    VC = COLOR.rgb;
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
    // --- [深度优化] 提取常量与折叠表达式 ---
    // 直接计算纯 Uniform 环境变量，触发 SPIR-V 编译器的常量折叠
    float c_env = cos(env_rotate);
    float s_env = sin(env_rotate);
    
    // 预组合不变的材质因子，利用结合律将 Uniform 剥离提取为一个单标量指令
    vec3 F0 = mix(vec3(0.04), BaseColorCenter, Metallic); 
    float uniform_kd_factor = (1.0 - Metallic) * diffuseIntensity;

    vec3 base_world_normal = normalize(World_N);
    vec3 N = base_world_normal;
    
    // 解析法线贴图及重构 TBN 切线空间矩阵
    if (useN) {
        vec3 map_n = texture(Normal_Tex, UV * NormalUV).rgb * 2.0 - 1.0;
        map_n.g = -map_n.g; // 翻转 Y/G 通道
        map_n = mix(vec3(0.0, 0.0, 1.0), map_n, normalIntensity);
        mat3 TBN = mat3(normalize(World_T), normalize(World_B), base_world_normal); 
        N = normalize(TBN * map_n); // 将切线空间法线转换到世界空间
    }

    float ndotv = clamp(dot(N, V), 0.0, 1.0);

    // Schlick 近似菲涅尔计算
    float f_pow = 1.0 - ndotv;
    float f2 = f_pow * f_pow;
    float Frenel = (f2 * f2 * f_pow) * 0.96 + 0.04;

    // 直接使用预组合因子，减少运行时乘法依赖
    float kd = uniform_kd_factor * (1.0 - Frenel);

    vec3 R = normalize(reflect(-V, N)); 

    // 计算基础颜色与法线菲涅尔边缘光的混合，去除局部无意义拷贝
    vec3 BaseColor = mix(BaseColorCenter, BaseColorEdge, BaseColor_Fresnel_Power * Frenel) * texture(Basecolor_Tex, UV * Basecolor_UV).rgb;
    if (useVertexColor) {
        BaseColor *= VC.r; // 叠加顶点颜色 R 通道
    }
    
    // 将 Min/Max 区间提前打包为 vec3，触发硬件 SIMD 混合指令进行批量插值
    vec3 raw_ors = texture(ORS_Tex, UV * ORS_UV).rgb;
    vec3 ors_min_vec = vec3(ao_Min, roughness_Min, shadow_Min);
    vec3 ors_max_vec = vec3(ao_Max, roughness_Max, shadow_Max);
    vec3 mapped_ors = mix(ors_min_vec, ors_max_vec, raw_ors);
    
    // 提取混合后的物理属性
    float ao = useVertexColor ? (raw_ors.r * mix(ao_Min, ao_Max, VC.r)) : mapped_ors.x;
    float roughness = mapped_ors.y;
    float shadow = mapped_ors.z;

    // --- 步骤 1：环境漫反射 (Irradiance) ---
	vec3 irradiance_dir = rotateAroundY(N, -c_env, -s_env);
	vec3 irradiance = textureLod(IrradianceMap, irradiance_dir, 0.0).rgb;

	// 仅控制 IrradianceMap 的饱和度
	float irradiance_luma = dot(irradiance, AP1_RGB2Y);
	irradiance = mix(vec3(irradiance_luma), irradiance, Irradiance_Saturation);

	vec3 diffuse = irradiance * BaseColor * kd;


    // --- 步骤 2：环境高光反射 (Prefiltered Env Map) ---
    vec3 prefilter_dir = rotateAroundY(R, c_env, s_env);
    vec3 prefilteredColor = textureLod(SkyLihgt, prefilter_dir, roughness * 4.0).rgb;
    
    vec2 scale_bias = EnvBRDFApprox_UE4(roughness, ndotv);
    vec3 specular = prefilteredColor * (F0 * scale_bias.x + scale_bias.y) * specularIntensity;
    
    vec3 final = diffuse + specular; // 基础底漆层输出
    
    // --- 步骤 3：Clearcoat 清漆层叠加 ---
    if(useClearcoat) {
        vec3 CR = normalize(reflect(-V, base_world_normal)); // 清漆层基于几何法线，不受法线凹凸贴图影响
        vec3 C_prefilter_dir = rotateAroundY(CR, c_env, s_env);
        vec3 C_prefilteredColor = textureLod(SkyLihgt, C_prefilter_dir, 0.0).rgb;
        
        float geom_ndotv = clamp(dot(base_world_normal, V), 0.0, 1.0);
        
        float a004 = min(0.9801, exp2(-9.28 * geom_ndotv)) * 0.99 + 0.042225;
        float c_factor = (0.9984 * a004 + 0.0015912) * clearcoat_Intensity; 
        
        final += C_prefilteredColor * c_factor; // 叠加清漆高光
    }

    // --- 步骤 4：色调映射与遮蔽合成输出 ---
    // 先乘以曝光，进行 ACES 压制后，再乘以阴影和 AO 输出给材质球系统
    ALBEDO = ACESFilm(final * Exposure) * (shadow * ao);
}
