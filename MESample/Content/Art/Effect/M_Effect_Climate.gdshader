shader_type spatial;
render_mode unshaded;
uniform sampler2D noise;
uniform bool visable = false;
uniform vec3 color:source_color = vec3(1);
void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	// Called for every pixel the material is visible on.
	vec2 uv = UV;

	uv.r = smoothstep(0,(1.0-UV.g)*0.8,UV.r);
	uv.r *= smoothstep(0.7,-0.1,UV.r);
	uv.g = smoothstep(0,0.2,UV.g);
	uv.g *= smoothstep(1,0.4,UV.g);
	vec3 c = vec3(1);
	vec4 n = texture(noise,UV*vec2(0.8,1)+vec2(0,-TIME*1.3));
	vec4 n2 = texture(noise,UV*vec2(1,0.5)+vec2(0.3,-TIME*0.5));
	ALBEDO = color;
	ALPHA = uv.r*uv.g*0.8 + pow(n.r,3)*uv.r*uv.g+pow(n.r,2)*uv.r*uv.g+pow(n2.r,2)*1.0*uv.r*uv.g*uv.r+pow(n2.r,3)*uv.r*uv.g;
	if(!visable)
	{
		ALPHA = 0.0;
	}
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
