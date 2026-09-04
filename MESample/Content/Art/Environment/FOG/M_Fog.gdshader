shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

// === 1. 基础参数 ===
group_uniforms Base_Settings;
uniform vec3 base_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float base_alpha : hint_range(0.0, 1.0) = 0.15;
uniform float color_brightness : hint_range(0.0, 20.0) = 1.0;
uniform float density_multiplier : hint_range(0.1, 20.0) = 4.0;
uniform sampler2D main_texture : source_color, repeat_enable; 
uniform float scroll_speed = 0.1;
uniform vec2 scroll_direction = vec2(0.0, 1.0); 
uniform float uv_edge_softness : hint_range(0.0, 0.5) = 0.1;

// === 2. 噪声贴图 ===
group_uniforms Noise_Layer_1;
uniform sampler2D noise1_texture : repeat_enable; 
uniform vec2 noise1_scroll_direction = vec2(1.0, 0.5); 
uniform float noise1_scroll_speed = 0.05;              

group_uniforms Noise_Layer_2;
uniform sampler2D noise2_texture : repeat_enable; 
uniform vec2 noise2_scroll_direction = vec2(-1.0, 0.2); 
uniform float noise2_scroll_speed = 0.03;              

// === 3. 渐变与视角 ===
group_uniforms Height_Fade;
uniform float fade_start_y = 0.0; 
uniform float fade_transition_distance : hint_range(0.01, 10.0) = 1.0; 

group_uniforms View_Visibility;
uniform vec3 target_view_direction = vec3(-0.778, -0.089, 0.621); 
uniform float max_visible_angle : hint_range(1.0, 180.0) = 90.0; 
uniform float view_angle_falloff : hint_range(0.1, 10.0) = 1.0;

// --- 优化 2: 减少 Varying 数量 ---
varying vec4 v_particle_info; // x: center_y, y: scale_y, z: inner_radius_sq, w: inv_fade_dist
varying vec4 v_view_info;     // x: angle_threshold, y: inv_angle_range
varying vec3 v_target_dir_view;
varying vec2 v_main_uv;
varying vec2 v_noise1_uv; 
varying vec2 v_noise2_uv; 

void vertex() {
    // 广告牌逻辑优化：直接构造缩放矩阵
    float scale_x = length(MODEL_MATRIX[0].xyz);
    float scale_y = length(MODEL_MATRIX[1].xyz);
    float scale_z = length(MODEL_MATRIX[2].xyz);
    
    MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
        vec4(INV_VIEW_MATRIX[0].xyz, 0.0), 
        vec4(INV_VIEW_MATRIX[1].xyz, 0.0), 
        vec4(INV_VIEW_MATRIX[2].xyz, 0.0), 
        MODEL_MATRIX[3]
    );
    MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
        vec4(scale_x, 0.0, 0.0, 0.0), 
        vec4(0.0, scale_y, 0.0, 0.0), 
        vec4(0.0, 0.0, scale_z, 0.0), 
        vec4(0.0, 0.0, 0.0, 1.0)
    );

    float hash = fract(sin(float(INSTANCE_ID) * 12.9898) * 43758.5453);
    float t = TIME + hash * 100.0;

    v_main_uv = UV + normalize(scroll_direction + 0.00001) * (t * scroll_speed);
    v_noise1_uv = UV + normalize(noise1_scroll_direction + 0.00001) * (t * noise1_scroll_speed);
    v_noise2_uv = UV + normalize(noise2_scroll_direction + 0.00001) * (t * noise2_scroll_speed);

    float inner_rad = 0.5 - uv_edge_softness;
    v_particle_info.x = MODEL_MATRIX[3].y; 
    v_particle_info.y = scale_y;
    v_particle_info.z = inner_rad * inner_rad;
    v_particle_info.w = 1.0 / max(0.0001, fade_transition_distance);

    float angle_cos = cos(radians(max_visible_angle));
    v_view_info.x = angle_cos;
    v_view_info.y = 1.0 / max(0.0001, 1.0 - angle_cos);

    v_target_dir_view = normalize((VIEW_MATRIX * vec4(normalize(target_view_direction), 0.0)).xyz);
}

void fragment() {
    vec2 centered_uv = UV - 0.5;
    float dist_sq = dot(centered_uv, centered_uv); 
    float circle_mask = smoothstep(0.25, v_particle_info.z, dist_sq);

    float n1 = texture(noise1_texture, v_noise1_uv).r;
    float n2 = texture(noise2_texture, v_noise2_uv).r;
    float combined_noise = n1 * n2 * density_multiplier;

    vec4 tex_color = texture(main_texture, v_main_uv);

    float virtual_y = v_particle_info.x + (0.5 - UV.y) * v_particle_info.y;
    float height_fade = clamp((virtual_y - fade_start_y) * v_particle_info.w, 0.0, 1.0);

    float view_dot = dot(normalize(-VIEW), v_target_dir_view);
    float direction_fade = clamp((view_dot - v_view_info.x) * v_view_info.y, 0.0, 1.0);
    direction_fade = pow(direction_fade, view_angle_falloff);

    // === 修改核心：颜色保持纯色，所有计算仅控制透明度 ===
    vec3 final_albedo = base_color * COLOR.rgb * color_brightness;  // 移除 tex_color.rgb，避免黑色脏污
    float final_alpha = base_alpha * COLOR.a * tex_color.a * combined_noise * circle_mask * height_fade * direction_fade;

    ALBEDO = final_albedo;
    ALPHA = clamp(final_alpha, 0.0, 1.0);
}
