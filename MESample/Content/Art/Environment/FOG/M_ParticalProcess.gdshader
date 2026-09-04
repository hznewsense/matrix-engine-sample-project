shader_type particles;

// === 核心控制参数 ===
uniform int amount = 10;             // 必须手动输入粒子总数，否则无法计算间距
uniform float line_length = 4.0;      // 线段总长度
uniform float jitter_amount : hint_range(0.0, 1.0) = 0.05; // 随机抖动（0为完全均匀）

// === 辅助参数 ===
uniform float rotation_angle = 0.0;   // 线段方向旋转
uniform vec3 center = vec3(0.0);      // 中心位置
uniform float initial_speed = 1.0;
uniform vec3 emission_direction = vec3(0.0, 1.0, 0.0);
uniform sampler2D gradient_texture : hint_default_white;

// 简单的随机函数
float rand(float seed) {
    return fract(sin(seed * 12.9898) * 43758.5453);
}

void start() {
    // 1. 初始化基础属性
    VELOCITY = normalize(emission_direction) * initial_speed;
    CUSTOM.x = TIME; // 记录出生时间

    // 2. 计算均匀分布比例 t (0.0 到 1.0)
    // 因为 Godot 无法自动获取 Amount，所以这里必须用我们定义的 uniform amount
    float t = 0.5;
    if (amount > 1) {
        t = float(INDEX) / float(amount - 1);
    }

    // 3. 添加微小的随机位移 (Jitter)
    // 当 jitter_amount 为 0 时，这里完全不影响位置
    float noise = rand(float(INDEX) + 1.234) - 0.5;
    t += noise * jitter_amount;

    // 4. 计算旋转和最终位置
    float angle_rad = radians(rotation_angle);
    vec3 line_dir = vec3(cos(angle_rad), 0.0, sin(angle_rad));
    
    // 线段分布计算：从 -length/2 到 +length/2
    vec3 final_pos = center + line_dir * (t * line_length - line_length / 2.0);

    // 赋值位置
    TRANSFORM[3].xyz = final_pos;
}

void process() {
    // 简单的持续运动逻辑
    TRANSFORM[3].xyz += VELOCITY * DELTA;

    // 颜色随生命周期变化
    float ratio = clamp((TIME - CUSTOM.x) / LIFETIME, 0.0, 1.0);
    COLOR = texture(gradient_texture, vec2(ratio, 0.0));
}