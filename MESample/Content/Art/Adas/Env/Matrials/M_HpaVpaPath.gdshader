shader_type spatial;
render_mode unshaded;
uniform vec3 basecolor :source_color= vec3(0.22,0.506,1.0);
uniform float Opacity = 0.8;
uniform float gra1 :hint_range(0.0, 1.0) = 0.0;
//uniform float gra2 :hint_range(0.0, 1.0);
uniform float power = 1.0;
void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	// Called for every pixel the material is visible on.
	float main =1.0- smoothstep(gra1,1,UV.g);
	//main *=1.0- smoothstep(gra2,1,1.0-UV.g);
	main = pow(main,power);
	ALBEDO = basecolor;
	ALPHA = main*Opacity;
}

//void light() {
	// Called for every pixel for every light affecting the material.
	// Uncomment to replace the default light processing function with this one.
//}
