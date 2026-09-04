shader_type spatial;
render_mode unshaded,world_vertex_coords,cull_disabled;
uniform float z_near = 19;
uniform float z_far  = 23;
uniform float  z_center = 10;
uniform float r_near = 28;
uniform float r_far  = 30;
uniform float Opacity  = 1.0;

uniform vec3 roadColor:source_color = vec3(0.5);
varying vec3 Vt;
varying vec3 Np;
void vertex() {
	// Called for every vertex the material is visible on.
	Vt = VERTEX;
	Np = NODE_POSITION_WORLD;
}

void fragment() {
	// Called for every pixel the material is visible on.
	
	vec2 uv = UV;
	float edgeAlpha = smoothstep(1,0.8,uv.r);
	
	float z_dis = distance(Vt.z,Np.z+z_center);
	z_dis = smoothstep(z_far,z_near,z_dis);
	float r_dis = distance(Vt.r,Np.r);
	r_dis = smoothstep(r_far,r_near,r_dis);
	
	ALBEDO = roadColor;
	ALPHA = edgeAlpha*z_dis*r_dis*Opacity;
}

//void light() {
	// Called for every pixel for every light affecting the material.
	// Uncomment to replace the default light processing function with this one.
//}
