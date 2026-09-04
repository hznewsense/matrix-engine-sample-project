shader_type canvas_item;
uniform sampler2D bg;
uniform sampler2D mask;
uniform vec2 size = vec2(2.25,1.48);
uniform vec2 offset = vec2(0.5,0.52);
uniform float radius = 0.05;
uniform float gradient_range = 0.5;
void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	// Called for every pixel the material is visible on.
	//vec2 p = SCREEN_UV-offset;
	//p.x*=1.305084745762712;
	//p*=5.0;
	vec3 color = texture(bg,SCREEN_UV).rgb;
//
	//vec4 r = vec4(radius);
    //r.xy = (p.x>0.0)?r.xy : r.zw;
    //r.x  = (p.y>0.0)?r.x  : r.y;
    //vec2 q = abs(p)-size+r.x;
	//float result = min(max(q.x,q.y),0.0) + length(max(q,0.0)) - r.x;
//
	//result = smoothstep(1.0-gradient_range,1,result);
//
	//float edge = step(SCREEN_UV.r,0.015);
	//edge +=1.0 - step(SCREEN_UV.r,0.995);
	//edge += step(SCREEN_UV.g,0.025);
	float result =1.0 - texture(mask,SCREEN_UV).r;
	COLOR.rgb =color;
	COLOR.a = result;
//	COLOR.a += edge;
	}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
