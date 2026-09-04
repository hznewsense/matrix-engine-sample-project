shader_type spatial;

render_mode unshaded;

// 自定义物体基础色
uniform vec3 base_color : source_color = vec3(0.2, 0.6, 0.8);



void fragment() {
    

    ALBEDO = base_color;
}
