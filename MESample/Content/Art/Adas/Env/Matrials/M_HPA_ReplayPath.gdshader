shader_type spatial;
render_mode unshaded,world_vertex_coords;
uniform vec3 color1:source_color= vec3(0.5);
uniform vec3 color2:source_color= vec3(0.2);
varying vec3 Vt;
void vertex() {
	// Called for every vertex the material is visible on.
	Vt = VERTEX;
}

void fragment() {
	// Called for every pixel the material is visible on.
	ALBEDO = mix(color1,color2,clamp(Vt.z+2.0,0,1));
	ALPHA = smoothstep(0,0.3,UV.g);
}

//void light() {
	// Called for every pixel for every light affecting the material.
	// Uncomment to replace the default light processing function with this one.
//}
