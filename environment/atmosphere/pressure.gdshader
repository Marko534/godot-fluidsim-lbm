shader_type spatial;

uniform sampler3D weather;
//uniform sampler3D wind_volume : hint_default_black, repeat_disable;
uniform float pressure_scale = 50.0;  // tweak this to see variation

varying vec3 wind;
varying float pressure;

void vertex() {
    float slice_y = sin(TIME*0.5) * 0.5 + 0.5;  // oscillates 0..1
	vec3 uvw  = vec3(UV.x, slice_y, UV.y);
    vec4 data = texture(weather, uvw);
    wind = data.xyz;
    pressure = data.w;
	VERTEX.y = slice_y;
}

void fragment() {
    float deviation = (pressure - 1.0) * pressure_scale;
    float vis       = deviation * 0.5 + 0.5;  // remap to 0..1
    ALBEDO          = vec3(vis);
}