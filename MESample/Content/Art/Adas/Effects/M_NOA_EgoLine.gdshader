shader_type spatial;
render_mode unshaded;
uniform vec3 baseColor :source_color = vec3(1.0);
uniform float hardness = 0.9064;
uniform float power = 0.606;
uniform float opacity = 1.0;
//uniform float edgeWidth = 1.0;
void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	// Called for every pixel the material is visible on.
	ALBEDO = baseColor;
	ALPHA = pow(UV.g*hardness,power)*opacity;
	//ALPHA += step(1.0-UV.g,edgeWidth/100.0);
}

//void light() {
	// Called for every pixel for every light affecting the material.
	// Uncomment to replace the default light processing function with this one.
//}
