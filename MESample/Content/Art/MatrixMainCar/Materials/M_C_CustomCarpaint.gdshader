// === 优化配置文件: M_C_CustomCarpaint.gdshader (包含附加高光与镜像修正) ===

shader_type spatial;
// 渲染模式：无光照模型(自定义光照)、使用世界坐标系顶点、禁用背面剔除
render_mode unshaded, world_vertex_coords, cull_disabled;

// ==========================================
// Uniforms: 材质参数面板定义
// ==========================================

group_uniforms Environment; // --- 环境光与反射设置 ---
uniform samplerCube SkyLihgt;                                  // 天空盒环境贴图：用于计算高光反射 (拼写保留原样)
uniform samplerCube IrradianceMap;                             // 辐照度贴图：用于计算漫反射全局光照 (GI)
uniform float env_rotate = 0.0;                                // 环境光旋转角度：控制环境贴图的水平旋转
uniform float env_saturate : hint_range(-1.0, 1.0, 0.01) = 0.0;// 环境光饱和度：调节最终渲染结果的色彩纯度

// 【新增】附加高光控制面板
group_uniforms Extra_Specular; 
uniform samplerCube ExtraSpecularMap;                                     // 附加高光贴图 (黑白)
uniform float extra_env_rotate = 0.0;                                     // 附加高光旋转角度：控制新贴图的水平旋转
uniform bool flip_extra_x = true;                                         // 翻转X轴：修正附加高光的左右镜像问题
uniform vec3 ExtraSpecularColor : source_color = vec3(1.0);               // 附加高光颜色：为黑白贴图染色
uniform float ExtraSpecularIntensity : hint_range(0.0, 10.0, 0.01) = 1.0; // 附加高光强度：控制新高光的亮度
uniform int cluster_cam_mark_layer : hint_range(0, 32, 1) = 0;            // 仪表相机标记层：该相机渲染时附加高光强度归零 (0=关闭)

group_uniforms Base_Color; // --- 底漆颜色与曝光设置 ---
uniform bool use_basecolor_tex = true;
uniform float base_tex_preserve : hint_range(0.0, 1.0, 0.01) = 0.8;
uniform float spec_restore_strength : hint_range(0.0, 2.0, 0.01) = 0.5;
uniform float tex_light_affect : hint_range(0.0, 1.0, 0.01) = 0.2;
uniform float base_tex_brightness : hint_range(0.0, 3.0, 0.01) = 1.15;
uniform sampler2D Basecolor_Tex : source_color;                // 底漆基础颜色贴图
uniform float Basecolor_UV = 1.0;                              // 基础颜色贴图的 UV 缩放系数
uniform vec3 BaseColorCenter : source_color = vec3(1.0);       // 正视底色：视线垂直于表面时看到的车漆颜色
uniform vec3 BaseColorEdge : source_color = vec3(0.75);        // 侧视底色：视线平行于表面(掠射角)时看到的颜色 (用于菲涅尔效果)
uniform float BaseColor_Fresnel_Power = 1.0;                   // 底色菲涅尔强度：控制正视与侧视颜色过渡的锐利度
uniform float Exposure : hint_range(0.0, 1.0, 0.01) = 0.7;     // 最终输出曝光度：控制材质的整体明暗

group_uniforms Attribute; // --- 表面物理属性设置 ---
uniform float Metallic : hint_range(0.0, 1.0, 0.01) = 0.0;     // 金属度权重：0为非金属，1为纯金属
uniform float roughness_Min : hint_range(0.0, 1.0, 0.01) = 0.5;// 粗糙度下限：映射贴图粗糙度的最小值
uniform float roughness_Max : hint_range(0.0, 1.0, 0.01) = 0.5;// 粗糙度上限：映射贴图粗糙度的最大值
uniform float diffuseIntensity = 1.0;                          // 漫反射强度：控制底漆接收环境漫反射的光量
uniform float specularIntensity = 1.0;                         // 高光反射强度：控制底漆对环境反射贴图的反射强度
uniform sampler2D ORS_Tex;                                     // 综合属性贴图：R通道=环境遮蔽(AO)，G通道=粗糙度，B通道=阴影遮罩

group_uniforms Flake_Settings; // --- 金属颗粒 (银粉) 设置 ---
uniform bool Use_Flake_Tex = true;                             // 颗粒开关：是否启用金属颗粒效果
uniform sampler2D Flake_Tex : hint_default_black;              // 颗粒噪波贴图：定义颗粒的分布状态
uniform bool Invert_Flake_Tex = true;                          // 反转颗粒贴图：是否将贴图颜色反相
uniform float Flake_UV_Scale = 100.0;                          // 颗粒UV缩放：数值越大，颗粒越细密
uniform float Flake_Intensity : hint_range(0.0, 10.0, 0.01) = 2.0; // 颗粒发光强度：控制颗粒闪烁的亮度
uniform float Flake_Roughness : hint_range(0.0, 1.0, 0.01) = 0.1;  // 颗粒表面粗糙度：影响颗粒反射的高光锐利度
uniform vec3 Flake_Color : source_color = vec3(1.0);           // 颗粒颜色：定义闪烁颗粒的基础色调

group_uniforms Normal; // --- 法线贴图设置 ---
uniform bool useN = false;                                     // 法线开关：是否启用表面凹凸细节
uniform sampler2D Normal_Tex : hint_normal;                    // 法线贴图：提供表面微观凹凸数据
uniform float NormalUV = 1.0;                                  // 法线UV缩放：法线贴图的平铺密度
uniform bool invert_normal_y = false;                          // 翻转法线Y通道：用于兼容 DirectX(需翻转) 或 OpenGL 格式的法线
uniform float normalIntensity : hint_range(0.0, 10.0, 0.01) = 0.5; // 法线强度：控制凹凸效果的深度

group_uniforms Clearcoat_and_Occlusion; // --- 清漆层与遮蔽设置 ---
uniform float clearcoat_Intensity = 1.0;                       // 清漆层强度：控制最外层透明涂层(如车身打蜡层)的反射强度
uniform float C_Roughness : hint_range(0.0, 1.0, 0.01) = 0.0;  // 清漆层粗糙度：通常接近0，表现极为光滑的镜面反射
uniform float ao_Min : hint_range(0.0, 1.0, 0.01) = 0.0;       // AO下限：映射环境遮蔽贴图的最小值
uniform float ao_Max : hint_range(0.0, 1.0, 0.01) = 1.0;       // AO上限：映射环境遮蔽贴图的最大值
uniform float shadow_Min : hint_range(0.0, 1.0, 0.01) = 0.0;   // 阴影下限：映射阴影贴图的最小值
uniform float shadow_Max : hint_range(0.0, 1.0, 0.01) = 1.0;   // 阴影上限：映射阴影贴图的最大值
uniform float clearcoat_edge_preserve : hint_range(0.0, 1.0, 0.01) = 0.25; // 边缘底漆保留度：防止掠射角底漆死黑


// ==========================================
// Varyings: 顶点与片元着色器间传递的变量
// ==========================================
varying vec3 V;       // 视线向量 (由顶点指向相机)
varying vec3 World_N; // 世界空间法线向量
varying vec3 World_T; // 世界空间切线向量
varying vec3 World_B; // 世界空间副切线向量


// ==========================================
// 辅助计算函数
// ==========================================
// ACES 电影级色调映射：防止高光过曝，让色彩过渡更自然
vec3 cheap_ACES(vec3 x) {
    float a = 2.51; float b = 0.03; float c = 2.43; float d = 0.59; float e = 0.14;
    return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

// 绕 Y 轴旋转向量：用于旋转环境光
vec3 rotateY(vec3 v, float c, float s) {
    return vec3(v.x * c + v.z * s, v.y, -v.x * s + v.z * c);
}

// 拟合环境光 BRDF：利用多项式近似计算基于图像的光照反射强度
vec2 EnvBRDFApprox(float Roughness, float NoV) {
    const vec4 c0 = vec4(-1.0, -0.0275, -0.572, 0.022);
    const vec4 c1 = vec4(1.0, 0.0425, 1.04, -0.04);
    vec4 r = Roughness * c0 + c1;
    float a004 = min(r.x * r.x, exp2(-9.28 * NoV)) * r.x + r.y;
    return vec2(-1.04, 1.04) * a004 + r.zw;
}


// ==========================================
// 顶点着色器 (Vertex Shader)
// ==========================================
void vertex() {
    // 提前在顶点阶段计算向量，减少片元阶段的性能开销
    V = CAMERA_POSITION_WORLD - VERTEX;
    World_N = NORMAL;
    World_T = TANGENT;
    World_B = BINORMAL;
}


// ==========================================
// 片元着色器 (Fragment Shader)
// ==========================================
void fragment() {
    // --- [深度优化] 提取常量与折叠表达式 ---
    // 提取环境旋转的三角函数值
    float c_sky = cos(env_rotate);
    float s_sky = sin(env_rotate);
    
    // 【新增】提取附加高光旋转的三角函数值及翻转符号
    float c_extra_sky = cos(extra_env_rotate);
    float s_extra_sky = sin(extra_env_rotate);
    float extra_x_sign = flip_extra_x ? -1.0 : 1.0; 
    
    // 基础参数预计算
    vec3 F0 = mix(vec3(0.04), BaseColorCenter, Metallic);     // 基础反射率
    float uniform_kd_factor = (1.0 - Metallic) * diffuseIntensity; // 漫反射能量守恒因子
    float uniform_sat_factor = 1.0 + env_saturate;            // 饱和度乘数

    // 向量化映射上下限，以便后续做向量插值
    vec3 ors_min_vec = vec3(ao_Min, roughness_Min, shadow_Min);
    vec3 ors_max_vec = vec3(ao_Max, roughness_Max, shadow_Max);

    // --- [分支消除] 使用数学计算代替 if 语句 ---
    vec3 flake_add_color = Flake_Color * (Flake_Intensity * 0.5);
    float flake_inv_sign = Invert_Flake_Tex ? -1.0 : 1.0;
    float flake_inv_bias = Invert_Flake_Tex ? 1.0 : 0.0;
    float ny_sign = invert_normal_y ? -1.0 : 1.0;

    // --- [代数极简化] 清漆层 BRDF 常量合并 ---
    float c_rough = max(C_Roughness, 0.01);
    float cr_x = 1.0 - c_rough; 
    float cr_y = c_rough * -0.0275 + 0.0425;
    float cr_x_sq = cr_x * cr_x;
    float cr_factor_const = c_rough * -0.00088 + 0.0016; 
    // ----------------------------------------------------

    // 基础向量归一化
    vec3 V_norm = normalize(V); 
    vec3 GeomN = normalize(World_N); // 几何法线
    vec3 N = GeomN;                  // 实际使用的法线（受法线贴图影响）
    
    // 处理法线贴图
    if (useN) {
        vec3 map_n = texture(Normal_Tex, UV * NormalUV).rgb * 2.0 - 1.0;
        map_n.y *= ny_sign; // 处理Y通道翻转
        
        map_n = mix(vec3(0.0, 0.0, 1.0), map_n, normalIntensity); // 调节法线强度
        map_n = normalize(map_n);
        N = normalize(mat3(normalize(World_T), normalize(World_B), GeomN) * map_n); // 切线空间转世界空间
    }

    // 预计算菲涅尔效应相关的点积
    float ndotv = clamp(dot(V_norm, N), 0.0, 1.0);
    float f_pow = 1.0 - ndotv;
    float f2 = f_pow * f_pow;
    float fresnel_weight = f2 * f2 * f_pow; // Schlick 菲涅尔近似展开
    float Frenel = fresnel_weight * 0.96 + 0.04;
    
    // 计算底漆颜色与漫反射衰减
    float kd = uniform_kd_factor * (1.0 - fresnel_weight);
    //vec3 BaseColor = mix(BaseColorCenter, BaseColorEdge, BaseColor_Fresnel_Power * Frenel) * texture(Basecolor_Tex, UV * Basecolor_UV).rgb;
	// --- BaseColor 模式切换 ---
	// 贴图颜色
	vec3 tex_base = texture(Basecolor_Tex, UV * Basecolor_UV).rgb;

	// 参数颜色
	vec3 CenterColor = BaseColorCenter;
	vec3 EdgeColor   = BaseColorEdge;

	// Fresnel 边缘色
	vec3 fresnel_color = mix(
	    CenterColor,
	    mix(CenterColor, EdgeColor, BaseColor_Fresnel_Power),
	    Frenel
	);

	// 🔥 开关控制
	vec3 BaseColor = use_basecolor_tex
	    ? tex_base
	    : fresnel_color;

    // 解析 ORS 综合属性贴图
    vec3 mapped_ors = mix(ors_min_vec, ors_max_vec, texture(ORS_Tex, UV * Basecolor_UV).rgb);
    float ao = mapped_ors.x;
    float roughness = mapped_ors.y;
    float shadow = mapped_ors.z;

    // 叠加金属颗粒（银粉）效果
    if (Use_Flake_Tex) {
        float raw_flake = texture(Flake_Tex, UV * Flake_UV_Scale).r;
        float flake_mask = clamp((flake_inv_bias + raw_flake * flake_inv_sign) * Flake_Intensity, 0.0, 1.0);
        BaseColor = mix(BaseColor, BaseColor + flake_add_color, flake_mask);
        roughness = mix(roughness, Flake_Roughness, flake_mask); // 颗粒区域覆盖特定的粗糙度
    }

    // --- 步骤 1：底层漫反射光照 ---
    // 采样辐照度贴图并叠加底漆颜色
    vec3 irradiance = textureLod(IrradianceMap, rotateY(N, -c_sky, -s_sky), 0.0).rgb;
    vec3 diffuse = irradiance * BaseColor * kd;

    // --- 步骤 2：底层高光反射 ---
    // 采样天空盒反射贴图并应用 BRDF 进行高光修正
    vec3 R = normalize(reflect(-V_norm, N));
    vec3 prefilteredColor = textureLod(SkyLihgt, rotateY(R, c_sky, s_sky), roughness * 4.0).rgb;
    
    // 【新增+修正】应用高光旋转及 X轴翻转
    vec3 extra_R = rotateY(R, c_extra_sky, s_extra_sky);
    extra_R.x *= extra_x_sign; // 处理左右镜像
    vec3 extra_prefilteredColor = textureLod(ExtraSpecularMap, extra_R, roughness * 4.0).rgb;
    // 仪表相机识别：ClusterViewport(仪表)相机通过 cull_mask 中的标记层判断，渲染时附加高光强度归零
    float extra_specular_strength = ExtraSpecularIntensity;
    if (cluster_cam_mark_layer > 0) {
        uint mark_bit = 1u << (uint(cluster_cam_mark_layer) - 1u);
        if ((CAMERA_VISIBLE_LAYERS & mark_bit) != 0u) {
            extra_specular_strength = 0.0;
        }
    }
    prefilteredColor += extra_prefilteredColor * ExtraSpecularColor * extra_specular_strength;

    vec2 scale_bias = EnvBRDFApprox(roughness, ndotv);
    vec3 specular = prefilteredColor * (F0 * scale_bias.x + scale_bias.y) * specularIntensity;

    // --- 步骤 3：表层清漆高光 ---
    // 清漆层使用几何法线而不是细节法线贴图，模拟表面的光滑平整
    vec3 CR = normalize(reflect(-V_norm, GeomN)); 
    vec3 C_prefilteredColor = textureLod(SkyLihgt, rotateY(CR, c_sky, s_sky), C_Roughness).rgb;
    
    // 【新增+修正】清漆层同步应用高光旋转及 X轴翻转
    vec3 extra_CR = rotateY(CR, c_extra_sky, s_extra_sky);
    extra_CR.x *= extra_x_sign; // 处理左右镜像
    vec3 C_extra_prefilteredColor = textureLod(ExtraSpecularMap, extra_CR, C_Roughness).rgb;
    C_prefilteredColor += C_extra_prefilteredColor * ExtraSpecularColor * extra_specular_strength;

    float geom_ndotv = clamp(dot(GeomN, V_norm), 0.0, 1.0);
    
    // 基于提取出的线性极简公式计算清漆 BRDF
    float a004 = min(cr_x_sq, exp2(-9.28 * geom_ndotv)) * cr_x + cr_y;
    float c_factor = (0.9984 * a004 + cr_factor_const) * clearcoat_Intensity;
    vec3 C_specular = C_prefilteredColor * c_factor;

    // --- 最终混合与后处理 ---
    // 根据粗糙度削弱环境遮蔽对高光的影响
    float cheap_spec_ao = mix(1.0, ao, roughness); 
    vec3 final_diffuse = diffuse * ao;
    vec3 final_specular = specular * cheap_spec_ao;
    
    // 能量守恒结合美术微调：使用 max 函数确保透射率不会低于我们设定的保留阈值
    float clearcoat_transmission = max(1.0 - c_factor, clearcoat_edge_preserve); 
    vec3 final_color = (final_diffuse + final_specular) * clearcoat_transmission + C_specular;

    // 饱和度调整：计算亮度后进行颜色插值
    float luminance = dot(final_color, vec3(0.2126, 0.7152, 0.0722)); 
    final_color = mix(vec3(luminance), final_color, uniform_sat_factor);
    
    // 应用阴影与曝光控制
    final_color = final_color * shadow * Exposure;
    
	// 原车漆完整结果
	vec3 paint_color = cheap_ACES(final_color);

	if (use_basecolor_tex) {
	    vec3 original_tex_color = texture(Basecolor_Tex, UV * Basecolor_UV).rgb;

	    // 提取车漆高光/清漆层
	    vec3 spec_layer = final_specular + C_specular;
	    spec_layer = cheap_ACES(spec_layer);

	    // 原贴图打底：不吃 Exposure，只少量吃 shadow
	    vec3 tex_base_lit = original_tex_color
	        * base_tex_brightness
	        * mix(1.0, shadow, tex_light_affect);

	    // 原图底色 + 车漆高光
	    vec3 decal_paint_color = tex_base_lit + spec_layer * spec_restore_strength;

	    // base_tex_preserve 越高，越偏原贴图打底
	    paint_color = mix(paint_color, decal_paint_color, base_tex_preserve);
	}

	ALBEDO = clamp(paint_color, 0.0, 1.0);
}
