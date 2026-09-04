shader_type spatial;
render_mode cull_disabled,unshaded,world_vertex_coords;
#define S(a) clamp(a,0.0,1.0)

group_uniforms common;
uniform samplerCube Env;
uniform float saturate:hint_range(-1.0, 5.0);
uniform float Intensity:hint_range(0.0, 2.0) = 1.0;
uniform float GroundIntensity:hint_range(0.0, 2.0) = 1.0;
uniform float blur :hint_range(0.0, 1.0) = 0.0;
uniform float rotate = 0.0;
uniform float sky_fov_y : hint_range(1.0, 179.0) = 40.0;
uniform float horizon_Dis = 10.0;
uniform float horizon_gradient = 1.0;

varying vec3 WP;
vec3 adjustSaturation(vec3 rgb, float saturation) {
    // 将RGB转换为HSV
	float r = rgb.r;
	float g = rgb.g;
	float b = rgb.b;
	b = b+(b-(r+g)/2.0)*saturation;
	g = g+(g-(b+r)/2.0)*saturation;
	r = r+(r-(b+g)/2.0)*saturation;
    // 将HSV转换回RGB
    return vec3(r,g,b);
}

// ============================================================
// Basic Helpers
// ============================================================
vec3 rotate_y(vec3 d, float a) {
    float s = sin(a);
    float c = cos(a);

    return vec3(
        c * d.x - s * d.z,
        d.y,
        s * d.x + c * d.z
    );
}

// ------------------------------------------------------------
// ACES RRT + ODT 拟合曲线
// ------------------------------------------------------------

vec3 rrtAndOdtFit(vec3 v)
{
    vec3 a = v * (v + 0.0245786) - 0.000090537;
    vec3 b = v * (0.983729 * v + 0.4329510) + 0.238081;
    return a / b;
}

vec3 acesFitted(vec3 color)
{
    // Linear sRGB / Rec.709
    // -> XYZ
    // -> D65 到 D60 白点适配
    // -> AP1 / ACEScg
    // -> RRT 饱和度调整

    const mat3 acesInputMat = mat3(
        vec3(0.59719, 0.07600, 0.02840),
        vec3(0.35458, 0.90834, 0.13383),
        vec3(0.04823, 0.01566, 0.83777)
    );

    // 近似表示：
    // ODT 饱和度调整
    // -> XYZ
    // -> D60 到 D65 白点适配
    // -> Linear sRGB / Rec.709

    const mat3 acesOutputMat = mat3(
        vec3( 1.60475, -0.10208, -0.00327),
        vec3(-0.53108,  1.10813, -0.07276),
        vec3(-0.07367, -0.00605,  1.07602)
    );

    color = max(color, vec3(0.0));
    color = acesInputMat * color;
    color = rrtAndOdtFit(color);
    color = acesOutputMat * color;

    return clamp(color, 0.0, 1.0);
}

void vertex() {
	// Called for every vertex the material is visible on.
	WP = VERTEX;
	  
}

void fragment() {
	// Called for every pixel the material is visible on.
	float aspect = VIEWPORT_SIZE.x / VIEWPORT_SIZE.y;	
    vec2 p = vec2( SCREEN_UV.x * 2.0 - 1.0,1.0 - SCREEN_UV.y * 2.0);
	float fov_scale = tan(radians(sky_fov_y) * 0.5);
	vec3 dir_view = normalize(vec3(
        p.x * aspect * fov_scale,
        p.y * fov_scale,
        -1.0
    ));
    vec3 dir_world = normalize((INV_VIEW_MATRIX * vec4(dir_view, 0.0)).xyz);
    dir_world = rotate_y(dir_world, rotate);

	float dis = distance(WP,vec3(0,0,0))*0.01;
	float gra = smoothstep(horizon_Dis,horizon_Dis+horizon_gradient,dis);
	vec3 sky = textureLod(Env,dir_world,mix(blur*7.0,0.0,gra)).rgb;
	sky = adjustSaturation(sky,saturate)*mix(GroundIntensity,Intensity,gra);
	sky = acesFitted(sky);
	ALBEDO = sky;
	//ALPHA = 0.2f;
	//ALBEDO = vec3(gra);
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
