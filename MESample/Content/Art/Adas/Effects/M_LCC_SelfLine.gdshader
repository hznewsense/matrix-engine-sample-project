shader_type spatial;
render_mode unshaded;
uniform vec3 basecolor:source_color = vec3(0.235,0.435,0.945);
uniform float hardness = 0.01;
uniform float opacity = 0.6;
void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	// Called for every pixel the material is visible on.
	float main = UV.g*(1.0-UV.g);
	main = smoothstep(0.0,hardness,main);
	ALBEDO = basecolor;

	ALPHA = main*opacity;
}

//void light() {
	// Called for every pixel for every light affecting the material.
	// Uncomment to replace the default light processing function with this one.
//}
