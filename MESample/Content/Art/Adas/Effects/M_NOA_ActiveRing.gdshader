shader_type spatial;
render_mode unshaded,world_vertex_coords;
#define saturate(a) clamp(a,0.00001,1.0)
varying vec3 Vt;
varying vec3 Cp;
varying vec3 Np;

uniform vec3 basecolor:source_color = vec3(0.235,0.435,0.945);

float c(float a,float b)
{
	if (a>b){return -0.5;};
	return a;
}

void vertex() {
	// Called for every vertex the material is visible on.
	float scale =mod(TIME*0.5,1.0) *  1.5;
	
	Vt = VERTEX/scale;
	Cp = CAMERA_POSITION_WORLD;
	Np = NODE_POSITION_WORLD/scale;
}

void fragment() {
	// Called for every pixel the material is visible on.
	float dis = length(Vt-Np);
	float r1,r2;
	r1 = smoothstep(0.01,2.0,dis-1.0);
	r2 = smoothstep(0.99,1,dis-1.0);
	float ring = saturate(r1-r2);
	ALBEDO =basecolor ;
	ALPHA = ring*(1.0-mod(TIME*0.5,1.0))*2.0;
}

//void light() {
	// Called for every pixel for every light affecting the material.
	// Uncomment to replace the default light processing function with this one.
//}
