shader_type spatial;
render_mode unshaded, cull_disabled; // 新增 cull_disabled 开启双面渲染

uniform vec3 emission_color : source_color = vec3(1.0, 1.0, 1.0); // 控制发光颜色
uniform float emission_intensity = 2.0; // 控制发光强度

void fragment() {
    // 在 unshaded 模式下，直接将颜色乘以强度输出到 ALBEDO
    ALBEDO = emission_color * emission_intensity;
}
