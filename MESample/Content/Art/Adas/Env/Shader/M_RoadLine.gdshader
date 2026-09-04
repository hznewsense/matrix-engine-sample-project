shader_type spatial;
render_mode unshaded;
uniform sampler2D tex_roadline;
uniform vec2 uv_scale = vec2(1);
uniform vec2 uv_offset;
uniform vec3 roadline_color:source_color = vec3(1.0);
uniform sampler2D noise;
varying vec3 Vt;
varying vec3 Cp;
varying vec3 Np;
void vertex() {
	// Called for every vertex the material is visible on.
	Vt = VERTEX;
	Cp = CAMERA_POSITION_WORLD;
	Np = NODE_POSITION_WORLD;
}

void fragment() {
	// Called for every pixel the material is visible on.
	vec2 uv = UV*uv_scale+uv_offset;
	ALBEDO = roadline_color;
	float n;
	ALPHA = texture(tex_roadline,uv).r;
	float road_noise = texture(noise,(Vt-Np).xz/1.0).r;
	road_noise =smoothstep(0.5,1,road_noise);
	//road_noise = 1.0-road_noise;
	ALPHA = ALPHA*road_noise;
}

//void light() {
	// Called for every pixel for every light affecting the material.
	// Uncomment to replace the default light processing function with this one.
//}
