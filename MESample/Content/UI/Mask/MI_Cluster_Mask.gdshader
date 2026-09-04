shader_type canvas_item;

uniform vec4 start_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 end_color   : source_color = vec4(0.0, 0.0, 0.0, 0.0);

// 0~1 控制方向：0=左到右，0.25=上到下，0.5=右到左，0.75=下到上
uniform float angle01 : hint_range(0.0, 1.0) = 0.0;

// 纯黑区域占比
uniform float black_range : hint_range(0.0, 1.0) = 0.7;

void fragment() {
    float angle = angle01 * 6.28318530718;
    vec2 dir = vec2(cos(angle), sin(angle));

    float p = dot(UV - vec2(0.5), dir) + 0.5;
    float t = clamp((p - black_range) / max(1.0 - black_range, 0.001), 0.0, 1.0);

    COLOR = mix(start_color, end_color, t);
}
