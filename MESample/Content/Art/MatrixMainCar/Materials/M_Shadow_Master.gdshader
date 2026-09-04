shader_type spatial;
render_mode unshaded;
uniform sampler2D tex;
uniform vec2 alpha = vec2(0.0,1.0);
uniform vec2 uvscale = vec2(1.0);
uniform vec2 uvoffest = vec2(0.5);
void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	// Called for every pixel the material is visible on.
	vec2 uv = UV;
	uv -= 0.5;
	uv *= uvscale;
	uv += uvoffest;
	uv = clamp(uv,0.0,1.0);
	ALBEDO = vec3(0.13)*0.1;
	float shadowmask = 1.0-texture(tex,uv).b;
	ALPHA = mix(alpha.x,alpha.y,shadowmask);
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
