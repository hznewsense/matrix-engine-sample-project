shader_type spatial;
render_mode unshaded; 

uniform vec3 emission_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float emission_intensity = 2.0;

uniform float saturation_multiplier : hint_range(0.0, 5.0) = 1.0;

// ===== 饱和度限制 =====
uniform bool enable_saturation_limit = false;
uniform float max_saturation : hint_range(0.0, 1.0) = 0.75;

// ===== 最低亮度保护 =====
uniform bool enable_min_luminance_protection = true;
uniform float min_luminance : hint_range(0.0, 1.0) = 0.35;


// ===== RGB -> HSV =====
vec3 rgb_to_hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0/3.0, 2.0/3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(
        abs(q.z + (q.w - q.y) / (6.0 * d + e)),
        d / (q.x + e),
        q.x
    );
}

// ===== HSV -> RGB =====
vec3 hsv_to_rgb(vec3 c) {
    vec3 rgb = clamp(abs(mod(c.x * 6.0 + vec3(0.0,4.0,2.0),6.0)-3.0)-1.0,0.0,1.0);
    return c.z * mix(vec3(1.0), rgb, c.y);
}


void fragment() {
    // ===== 1. 亮度 =====
    float luminance = dot(emission_color, vec3(0.2126, 0.7152, 0.0722));
    vec3 grayscale = vec3(luminance);
    
    // ===== 2. 饱和度调整 =====
    vec3 adjusted_color = mix(grayscale, emission_color, saturation_multiplier);
    adjusted_color = max(adjusted_color, vec3(0.0));

    // ===== 3. 饱和度限制（可选）=====
    if (enable_saturation_limit) {
        vec3 hsv = rgb_to_hsv(adjusted_color);
        hsv.y = min(hsv.y, max_saturation);
        adjusted_color = hsv_to_rgb(hsv);
    }

    // ===== 4. 最低亮度保护（重点保留）=====
    if (enable_min_luminance_protection) {
        float current_luma = dot(adjusted_color, vec3(0.2126, 0.7152, 0.0722));

        if (current_luma > 0.0001 && current_luma < min_luminance) {
            float boost = min_luminance / current_luma;
            adjusted_color *= boost;
        }
    }

    // ===== 5. 输出 =====
    ALBEDO = adjusted_color * emission_intensity;
}
