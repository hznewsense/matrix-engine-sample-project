shader_type spatial;
render_mode unshaded;
#define S(a) clamp(a,0.0,1.0)
uniform vec3 baseColor :source_color = vec3(1.0);
uniform float range = 0.2;
uniform float naer_far = 10.0;
uniform float gRange = 0.15;

void vertex() {
	
	// Called for every vertex the material is visible on.
}

void fragment() {
	// Called for every pixel the material is visible on.
	float main = UV.g*(1.0-UV.g);
	main = smoothstep(0.0,range,main);
	
	vec2 uv = UV;
	float ux = S(uv.x*(1.0-uv.x)*4.0);
	float uy = smoothstep(S(uv.y),0.0,0.01);
	uy =min(uy, smoothstep(S(1.0-uv.y),0.0,0.05));
		uy =min(uy, smoothstep(S(uv.y),0.0,0.05));
	ux =smoothstep(S(ux),0.0,gRange);
	
	float mask = step(UV.x,0.2)+step(0.8,UV.x)+step(UV.y,0.05)+step(0.95,UV.y)*100.0;
	ALBEDO = baseColor;
	
	ALPHA = clamp(ux*uy-mask,0,1);

}
//void light() {
	// Called for every pixel for every light affecting the material.
	// Uncomment to replace the default light processing function with this one.
//}
