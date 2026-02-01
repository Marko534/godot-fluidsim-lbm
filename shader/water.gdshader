shader_type spatial;

uniform vec3 albedo : source_color =  vec3(0.0, 0.322, 0.431);
uniform vec3 albedo_fresnel : source_color =  vec3(0.0, 0.322, 0.431);
uniform float metallic : hint_range(0.0, 1.0) = 0;
uniform float roughness : hint_range(0.0, 1.0) = 0.02;
uniform sampler2D wave;
uniform sampler2D wave_normal;
uniform sampler2D texture_normal;
uniform sampler2D texture_normal2;
uniform vec2 wave_direction = vec2(2.0,0.0);
uniform vec2 wave_direction2 = vec2(0.0,1.0);
uniform float time_scale : hint_range(0.0, 0.2, 0.005) = 0.025;
uniform float noise_scale = 10.0;
uniform float height_scale = 0.15;

varying float height;
varying vec3 world_pos;


float fresnel(float amount, vec3 normal, vec3 view)
{
	return pow((1.0 - clamp(dot(normalize(normal), normalize(view)), 0.0, 1.0 )), amount);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	height = texture(wave, world_pos.xz / noise_scale + TIME * time_scale).r;
	VERTEX.y += height * height_scale;
}

void fragment() {
	// Time catcutatills for wave (normal map) movement
	vec2 time = (TIME * wave_direction) * time_scale; // Movement rate of first wave

	vec2 time2 = (TIME * wave_direction2) * time_scale; // Movement rate of second wave

// Blend normal maps into one
	vec3 normal_blend = texture(wave_normal,  world_pos.xz / noise_scale  + TIME * time_scale).rgb;
	//vec3 normal_blend = mix(texture(texture_normal,world_pos.xz + time).rgb, texture(texture_normal2,world_pos.xz + time2).rgb, 0.5);
	
	// Calculate Fresnel
	float fresnel = fresnel(5.8, NORMAL, VIEW);
	vec3 surface_color = mix(albedo, albedo_fresnel, fresnel);
	
	ALBEDO = surface_color;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	
	NORMAL_MAP = normal_blend;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
