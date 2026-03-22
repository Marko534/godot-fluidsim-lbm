shader_type spatial;

uniform sampler3D wind_volume;
//uniform sampler3D wind_volume : hint_default_black, repeat_disable;
uniform float height_scale = 0.5;
uniform int NX = 64;
uniform int NY = 32;
uniform int NZ = 64;

varying vec3 wind;

void vertex() {
    float slice_y = sin(TIME) * 0.5 + 0.5;  // oscillates 0..1
    //float slice_y = 0.5;  // oscillates 0..1
    vec3 uvw = vec3(UV.x, slice_y, UV.y);
    wind = texture(wind_volume, uvw).xyz;
	VERTEX.y = slice_y;
}

void fragment() {
    ALBEDO = wind.xyz;
}