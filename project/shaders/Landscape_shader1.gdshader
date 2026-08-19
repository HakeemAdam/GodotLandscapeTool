shader_type spatial;
render_mode  specular_toon;

 

uniform vec3 water_color = vec3(0.05, 0.15, 0.25);
uniform vec3 ground_color = vec3(0.86, 0.52, 0.14);
uniform vec3 grass_color = vec3(0.22, 0.38, 0.18);
uniform vec3 rock_color = vec3(0.35, 0.33, 0.32);

uniform sampler2D text;
uniform sampler2D nm;

uniform float scale = 10.0;


varying vec3 world_pos;
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	
	
	
	float height = clamp((world_pos.y - 0.0)/ scale, -1.0, 1.0);

	float blend1 = step( -0.5, height);
	vec3 current_color = vec3(0.0);
	
	current_color = mix(water_color, ground_color, blend1);
	
	float blend2 = step( 0.25, height);
	current_color = mix(current_color, grass_color, blend2);
	
	float blend3 = step(0.98, height);
	current_color = mix(current_color, rock_color, blend3);
	
	
	vec4 sample_color = texture(text, UV);

	
	//ALBEDO = sample_color.rgb;
	ALBEDO = mix( sample_color.rgb, current_color, height);
	ROUGHNESS = 0.9;
	SPECULAR = 0.1;

}

/*void light() {
	float dot_product = dot(NORMAL, LIGHT);
	float toon_light = smoothstep(0.0, 0.5, dot_product);
	
	vec3 shadow_color = ALBEDO * 0.15;
	vec3 final_light = mix(shadow_color, LIGHT_COLOR, toon_light);
	
	DIFFUSE_LIGHT += final_light * ATTENUATION;
}*/
