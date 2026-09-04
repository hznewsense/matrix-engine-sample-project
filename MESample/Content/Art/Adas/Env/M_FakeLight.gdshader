shader_type spatial;
render_mode unshaded;

varying vec3 Vt;
varying vec3 Cp;
void vertex() {
	// Called for every vertex the material is visible on.

	Vt = VERTEX;
	Cp = CAMERA_POSITION_WORLD - NODE_POSITION_WORLD;
}

void fragment() {
	// Called for every pixel the material is visible on.
	vec3 N = normalize((vec4(NORMAL,0)*VIEW_MATRIX).rgb);
	vec3 V = normalize(Cp-Vt);
	float d = distance(Vt,vec3(0));
	float f = 1.0-dot(N,V);
	d = 1.0-d;
	ALPHA = d*0.5*(f);

}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
