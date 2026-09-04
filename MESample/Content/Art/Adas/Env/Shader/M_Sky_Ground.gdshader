shader_type spatial;
render_mode cull_disabled,unshaded,world_vertex_coords;
#define S(a) clamp(a,0.0,1.0)

group_uniforms common;
uniform vec3 BaseColor:source_color = vec3(0.5);
uniform float saturate:hint_range(-1.0, 5.0);
uniform float Intensity:hint_range(0.0, 2.0) = 1.0;
uniform bool IsParking = false;

group_uniforms Texture;
uniform samplerCube Env : filter_linear_mipmap, repeat_enable;
uniform bool InvertY = false;
uniform bool FlipBottomX = false;
uniform float RotationY: hint_range(0.0, 360.0) = 0.0;

vec3 rotateY(vec3 dir, float degrees)
{
	float a = radians(degrees);
	float s = sin(a);
	float c = cos(a);

	return vec3(
		dir.x * c - dir.z * s,
		dir.y,
		dir.x * s + dir.z * c
	);
}

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

vec3 fixCubeTopBottom(vec3 dir)
{
	float ax = abs(dir.x);
	float ay = abs(dir.y);
	float az = abs(dir.z);

	// 只处理 cubemap 的上/下面
	if (ay >= ax && ay >= az)
	{
		// 先交换上下面
		dir.y = -dir.y;
		if (FlipBottomX)
		{
			dir.x = -dir.x;
		}
	}

	return dir;
}

void fragment() {
	if(IsParking)
	{
		ALBEDO = BaseColor;
	}
	else
	{
	vec3 N = - normalize((vec4(NORMAL,0.0)*VIEW_MATRIX).rgb);
	
	if(InvertY){N = fixCubeTopBottom(N);}// 交换 cubemap 的上下面
	N = rotateY(N, RotationY);
	vec3 sky = texture(Env,N).rgb;
	sky = adjustSaturation(sky,saturate)*Intensity;
	ALBEDO = sky;
		
	}
	//ALBEDO = vec3(0.5);
}

//void light() {
	// Called for every pixel for every light affecting the material.
	// Uncomment to replace the default light processing function with this one.
//}
