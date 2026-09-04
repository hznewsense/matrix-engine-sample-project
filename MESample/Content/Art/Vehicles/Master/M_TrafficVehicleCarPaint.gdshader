shader_type spatial;
render_mode unshaded;

uniform sampler2D tex;
uniform float aoInt = 0.5;
uniform sampler2D basecolorTex;
uniform bool usebasecolorTex= false;
uniform vec3 basecolor :source_color= vec3(0.818,0.883,0.94);//(0.354,0.438,0.521);
uniform float texInt = 0.7;
uniform vec3 LightDirection = vec3(0.95,31.335,3.99);
uniform float LightInt = 5.0;

void vertex() {
	// Called for every vertex the material is visible on.
}
vec3 ACESToneMapping(vec3 x)
{
    float a = 2.51f;
    float b = 0.03f;
    float c = 2.43f;
    float d = 0.59f;
    float e = 0.14f;
    return clamp((x*(a*x+b))/(x*(c*x+d)+e),0,1);
}

void fragment() {
	// Called for every pixel the material is visible on.
	vec3 N = (vec4(NORMAL,0)*VIEW_MATRIX).rgb;
//	vec3 L = normalize(LightDirection);
	vec3 L = vec3(-0.4402,0.8907,0.1134);
	float ao = mix(aoInt,1.0,texture(tex,UV).r);
	vec3 btex =vec3(0.0);

	if(usebasecolorTex){
		btex = texture(basecolorTex,UV).rgb*texInt;
		}
	vec3 FinalColor =mix(basecolor,basecolor*LightInt,vec3(pow(dot(N,L)*0.5+0.5,6)));
	ALBEDO = ao*FinalColor+btex;
	ALBEDO = ACESToneMapping(ALBEDO);
	ALBEDO*=ALBEDO;

//ALBEDO = FinalColor;
}

//void light() {
	// Called for every pixel for every light affecting the material.
	// Uncomment to replace the default light processing function with this one.
//}
