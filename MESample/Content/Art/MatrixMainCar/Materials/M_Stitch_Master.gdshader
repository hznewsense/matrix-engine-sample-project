shader_type spatial;
render_mode unshaded;

uniform sampler2D main_tex : source_color;
uniform vec4 tint_color : source_color = vec4(1.0);

void fragment() {
    vec4 tex = texture(main_tex, UV);
    vec4 col = tex * tint_color;

    ALBEDO = col.rgb;
    ALPHA = col.a;
}
