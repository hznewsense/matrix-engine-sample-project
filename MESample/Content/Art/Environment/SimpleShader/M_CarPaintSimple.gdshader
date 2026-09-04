shader_type spatial;
render_mode unshaded, world_vertex_coords, cull_disabled;

group_uniforms Base_Color;
uniform sampler2D Basecolor_Tex;
uniform vec3 BaseColorCenter : source_color = vec3(1.0);

void fragment() {
    vec3 base_color = texture(Basecolor_Tex, UV).rgb * BaseColorCenter;
    ALBEDO = base_color;
}
