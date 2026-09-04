shader_type spatial;
render_mode unshaded;
uniform sampler2D lighttex;
uniform float breakInt = 0;
uniform vec3 breakColor :source_color = vec3(1.0,0.0,0.0);
uniform vec3 tColor :source_color = vec3(1.0,0.5,0.0);
uniform float leftInt = 0;
uniform float rightInt = 0;
uniform float speed = 1.0;


uniform sampler2D tex;
uniform float aoInt = 0.5;
uniform sampler2D basecolorTex;
uniform bool usebasecolorTex= false;
uniform vec3 basecolor :source_color= vec3(0.818,0.883,0.94);
uniform float texInt = 0.7;
uniform vec3 LightDirection = vec3(0.95,31.335,3.99);
uniform float LightInt = 5.0;

vec3 ACESToneMapping(vec3 x)
{
    float a = 2.51f;
    float b = 0.03f;
    float c = 2.43f;
    float d = 0.59f;
    float e = 0.14f;
    return clamp((x*(a*x+b))/(x*(c*x+d)+e),0,1);
}
vec3 gamma(vec3 c,float g)
{
	return vec3(pow(c.r,g),pow(c.g,g),pow(c.b,g));
}

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	// Called for every pixel the material is visible on.
	float blink = round(mod(TIME*speed,1.0));
	vec3 t = texture(lighttex,UV).rgb;
	vec3 bre = t.r*breakColor*breakInt*5.0;
	vec3 lef = t.g*tColor*leftInt*blink*5.0;
	vec3 rig = t.b*tColor*rightInt*blink*5.0;
	float lightMask = t.r*breakInt+t.g*leftInt*blink+t.b*rightInt*blink;
	lightMask = 1.0-lightMask;
	vec3 N = (vec4(NORMAL,0)*VIEW_MATRIX).rgb;
	vec3 L = normalize(LightDirection);
	float ao = mix(aoInt,1.0,texture(tex,UV).g);
	vec3 btex =vec3(0.0);
	//vec3 bbase = vec3(0.4);
	if(usebasecolorTex){
		btex = texture(basecolorTex,UV).rgb*texInt;
		//bbase = vec3(0.0);
		}
	vec3 FinalColor =mix(basecolor,basecolor*LightInt,vec3(pow(dot(N,L)*0.5+0.5,4)));
	//ALBEDO =vec3(ao.g)*basecolor*btex;
	ALBEDO = ao*FinalColor+btex;
	vec3 carLight =bre+lef+rig;
	ALBEDO = ALBEDO*lightMask +carLight;
	ALBEDO = ACESToneMapping(ALBEDO);
	ALBEDO = gamma(ALBEDO,2.2);
	//ALBEDO = vec3(blink);
}

//void light() {
	// Called for every pixel for every light affecting the material.
	// Uncomment to replace the default light processing function with this one.
//}
