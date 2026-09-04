shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec3 emission_color : source_color = vec3(1.0, 1.0, 1.0); 
uniform float emission_intensity = 2.0; 

// --- 新增：渐变控制参数 ---
// 范围设为 -0.5 到 1.5，确保渐变效果可以完全移出模型两端
uniform float fade_position : hint_range(-0.5, 1.5) = 0.5; // 控制渐变的高度（中心点）
uniform float fade_softness : hint_range(0.001, 1.0) = 0.2; // 控制渐变的柔和度（过渡带宽度）

void fragment() {
    // 1. 发光颜色计算
    ALBEDO = emission_color * emission_intensity;
    
    // 2. 透明度渐变计算
    // 计算渐变的上下边界
    float fade_bottom = fade_position + fade_softness;
    float fade_top = fade_position - fade_softness;
    
    // 使用 smoothstep 根据 UV.y 进行平滑插值
    float alpha = smoothstep(fade_top, fade_bottom, UV.y);
    
    // 3. 输出透明度
    ALPHA = alpha;
}
