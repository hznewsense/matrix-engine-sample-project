shader_type spatial;

//uniform sampler2D MainTex ;
//uniform float emission_intensity : hint_range(0.0f, 10.0f) = 1.0f;
//uniform float albedo_intensity : hint_range(0.0f, 10.0f) = 1.0f;
uniform vec3 emission_color:source_color = vec3(0.5f);
//uniform vec3 albedo_color = vec3(1.0f,1.0f,1.0f);
//uniform vec2 alpha_Scale = vec2(1.0f,200.0f);
//uniform vec2 alpha_Offset = vec2(0.0f,0.0f);
uniform float alpha_pow = 2.0f;

void fragment() {

	//vec2 UV_Offset = vec2(alpha_Offset.x,alpha_Offset.y * TIME );
	//vec2 final_UV = UV * alpha_Scale + UV_Offset;

	//float alpha =  texture(MainTex,final_UV).r;
	//ALPHA = alpha;

	//EMISSION = emission_color * emission_intensity;

	ALBEDO = emission_color.rgb ;
	ALPHA = pow(UV.y,alpha_pow);
}

//void light() {
	// Called for every pixel for every light affecting the material.
	// Uncomment to replace the default light processing function with this one.
//}
