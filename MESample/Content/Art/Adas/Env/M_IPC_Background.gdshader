shader_type spatial;
render_mode unshaded,cull_disabled;
uniform bool darkMode_P = false;
uniform sampler2D bg;
void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	// Called for every pixel the material is visible on.
	ALBEDO = texture(bg,SCREEN_UV).rgb;
	if(darkMode_P == true)
	{
		ALBEDO+=0.02;
	}
//	ALBEDO = vec3(1);
}

//void light() {
	// Called for every pixel for every light affecting the material.
	// Uncomment to replace the default light processing function with this one.
//}
