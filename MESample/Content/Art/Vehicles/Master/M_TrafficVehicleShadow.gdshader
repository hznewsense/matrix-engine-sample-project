shader_type spatial;
render_mode unshaded;
uniform sampler2D shadow;
uniform vec2 uvscale = vec2(1);
uniform vec2 uvoffset = vec2(0);
uniform vec2 alpha = vec2(-0.102,1.3);
void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	// Called for every pixel the material is visible on.
	vec2 uv = UV;
	uv-=0.5;
	uv*=uvscale;
	uv+=0.5;
	uv+=uvoffset;
	uv = clamp(uv,0.0,1.0);
	ALBEDO = vec3(0.13);
	float shadowMask = 1.0-texture(shadow,uv).g;
	ALPHA =mix(alpha.x,alpha.y,shadowMask);
	//ALPHA = 0.0;
}

//void light() {
	// Called for every pixel for every light affecting the material.
	// Uncomment to replace the default light processing function with this one.
//}
