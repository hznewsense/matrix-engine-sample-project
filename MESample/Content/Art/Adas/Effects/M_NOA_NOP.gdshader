shader_type spatial;
render_mode unshaded,world_vertex_coords;
#define S(a) clamp(a,0.0,1.0)

uniform vec2 meshScale = vec2(2.0,1.0);
uniform float width:hint_range(0.0, 0.5) = 0.05;
uniform vec2 inScale = vec2(1.0);
uniform vec2 inRange = vec2(1.0);
uniform vec3 incolor:source_color = vec3(0.,0.368,0.92);
uniform vec3 edgecolor:source_color = vec3(1.0);
uniform float radius = 0.07;
uniform float alpha = 1.0;


float sdRoundBox(vec2 p,vec2 b,vec4 r)
{
	r.xy = (p.x>0.0)?r.xy : r.zw;
    r.x  = (p.y>0.0)?r.x  : r.y;
    vec2 q = abs(p)-b+r.x;
    return ceil( min(max(q.x,q.y),0.0) + length(max(q,0.0)) - r.x);

}

float boxMask(vec2 A,vec2 B,vec2 Bounds,float EdgeFalloff)
{
	return 1.0-clamp(length(max(abs(A-B)-Bounds,0))/EdgeFalloff,0.0,1.0);
}

float fourRound(vec2 uv,vec2 Scale,vec2 range,float r)
{
	vec2 b = range*Scale;
	vec2 uv_lt = uv*Scale;
	vec2 uv_rt = vec2(1.0-uv.r,uv.g)*Scale;
	vec2 uv_ld = vec2(uv.r,1.0-uv.g)*Scale;
	vec2 uv_rd = vec2(1.0-uv.r,1.0-uv.g)*Scale;
	return ceil(sdRoundBox(uv_lt,b,vec4(r,1.0,1.0,1.0))
	+ sdRoundBox(uv_rt,b,vec4(r,1.0,1.0,1.0))
	+ sdRoundBox(uv_ld,b,vec4(r,1.0,1.0,1.0))
	+ sdRoundBox(uv_rd,b,vec4(r,1.0,1.0,1.0)));
}

void vertex() {

}

void fragment() {
	// Called for every pixel the material is visible on.
	vec2 outScale = vec2(meshScale.x/meshScale.y,1.0);
	vec2 ir = vec2(1.0-S(width*S(meshScale.y/meshScale.x)),1.0-S(width*S(meshScale.x/meshScale.y)));

	float outResult =clamp( fourRound(UV, outScale,vec2(1.0),radius),0.0,1.0);
	float inResult =clamp( fourRound(UV, outScale*inScale,inRange*ir,radius-0.02),0.0,1.0);
	vec3 icolor = incolor*(1.0-inResult);
	vec3 ecolor = edgecolor*(inResult-outResult);
	float centerFallof = pow(1.0- boxMask(UV,vec2(0.5),vec2(0.2),0.6),1.742)*1.14;
	centerFallof*=ceil(boxMask(UV,vec2(0.5),vec2(0.9),0.1));
	ALBEDO = ecolor+icolor;
	ALPHA = (1.0-outResult)*centerFallof*alpha+(inResult-outResult)*alpha;
	
}

//void light() {
	// Called for every pixel for every light affecting the material.
	// Uncomment to replace the default light processing function with this one.
//}
