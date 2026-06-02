shader_type particles;

uniform sampler3D weather : hint_default_black, repeat_disable;
uniform vec3 size = vec3(1.0,1.0,1.0);
uniform float wind_strength  = 0.75;
uniform float min_scale      = 0.3;
uniform float max_scale      = 3.0;
uniform float stretch_factor = 8.0;

float rand(float seed) {
    return fract(sin(seed) * 43758.5453);
}

void start() {

    TRANSFORM[3].xyz = (EMISSION_TRANSFORM * vec4(
        (rand(float(INDEX) + TIME)       * 2.0 - 1.0) * size.x,
        (rand(float(INDEX) + TIME + 1.0) * 2.0 - 1.0) * size.y,  // centered
        (rand(float(INDEX) + TIME + 2.0) * 2.0 - 1.0) * size.z,
        1.0
    )).xyz;
    VELOCITY = vec3(0.0);
    ACTIVE   = true;
}

void process() {

    vec3 local_p = TRANSFORM[3].xyz - EMISSION_TRANSFORM[3].xyz;

	// Kill outside box — Y now centered like X and Z
	if(local_p.x < -size.x || local_p.x > size.x ||
	   local_p.y < -size.y  || local_p.y > size.y ||
	   local_p.z < -size.z  || local_p.z > size.z){
	    ACTIVE = false;
	}
	
	// UVW — remap -1..1 to 0..1 for Y too
	vec3 uvw = vec3(
	    (local_p.x + size.x) / (size.x * 2.0),
	    (local_p.y + size.y) / (size.y * 2.0),  // centered
	    (local_p.z + size.z) / (size.z * 2.0)
	);

    vec3  wind       = texture(weather, uvw).xyz;
    float wind_speed = length(wind);

    VELOCITY         = wind * wind_strength;
    TRANSFORM[3].xyz += VELOCITY * DELTA;

    COLOR = vec4(0.75 - normalize(VELOCITY) * 0.75, 1.0);

    if(wind_speed > 0.005){
        vec3 up      = normalize(wind);
        vec3 forward = vec3(0.0, 0.0, 1.0);
        if(abs(dot(up, forward)) > 0.999)
            forward  = vec3(1.0, 0.0, 0.0);
        vec3 right   = normalize(cross(up, forward));
        forward       = normalize(cross(right, up));

        float t          = clamp(wind_speed, 0.0, 1.0);
        float base_scale = mix(min_scale, max_scale, t);
        float stretch    = 1.0 + wind_speed * stretch_factor;

        TRANSFORM[0].xyz = right   * base_scale;
        TRANSFORM[1].xyz = up      * base_scale * stretch;
        TRANSFORM[2].xyz = forward * base_scale;
    } else {
        ACTIVE = false;
    }
}