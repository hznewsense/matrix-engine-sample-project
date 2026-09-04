shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_back, unshaded;

uniform sampler2D tiling_mask : source_color;
uniform vec2 uv_scale = vec2(1.0, 1.0);
uniform float contrast_mask : hint_range(0.0, 8.0) = 1.0;

uniform float radius : hint_range(0.001, 2.0) = 0.5;
uniform vec2 center_position = vec2(0.5, 0.5);

uniform float fresnel_exponent : hint_range(0.01, 8.0) = 1.0;
uniform float fresnel_power : hint_range(0.0, 8.0) = 1.0;

uniform vec4 emission_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

float radial_gradient(vec2 uv, vec2 center, float r) {
    float dist = distance(uv, center);
    return clamp(1.0 - dist / r, 0.0, 1.0);
}

void fragment() {
    // uv_scale 表示“平铺大小”
    vec2 uv = fract(UV * uv_scale);

    float mask = texture(tiling_mask, uv).g;
    float mask_pow = pow(max(mask, 0.0001), contrast_mask);

    float lerp_value = mix(1.0, 4.0, mask_pow);

    float grad = radial_gradient(uv, center_position, radius);
    float radial_mask = pow(max(grad, 0.0001), lerp_value);

    vec3 n = normalize(NORMAL);
    vec3 v = normalize(VIEW);

    float ndotv = clamp(dot(n, v), 0.0, 1.0);
    float fresnel = pow(1.0 - ndotv, fresnel_exponent);
    float angle_protection = clamp((1.0 - fresnel) * fresnel_power, 0.0, 1.0);

    float final_alpha = clamp(radial_mask * angle_protection, 0.0, 1.0);

    ALBEDO = emission_color.rgb;
    ALPHA = final_alpha * emission_color.a;
    EMISSION = emission_color.rgb;
}
