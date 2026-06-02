shader_type particles;

uniform sampler3D weather : hint_default_black, repeat_disable;
uniform float wind_strength  = 1.0;
uniform float min_scale      = 0.2;
uniform float max_scale      = 4.0;
uniform float stretch_factor = 8.0;

float rand(float seed) {
    return fract(sin(seed) * 43758.5453);
}

void start() {
    vec3 box_size = vec3(
        length(EMISSION_TRANSFORM[0].xyz),
        length(EMISSION_TRANSFORM[1].xyz),
        length(EMISSION_TRANSFORM[2].xyz)
    );
    TRANSFORM[3].xyz = (EMISSION_TRANSFORM * vec4(
        (rand(float(INDEX) + TIME)       * 2.0 - 1.0) * box_size.x,
        (rand(float(INDEX) + TIME + 1.0) * 2.0 - 1.0) * box_size.y,  // centered
        (rand(float(INDEX) + TIME + 2.0) * 2.0 - 1.0) * box_size.z,
        1.0
    )).xyz;
    VELOCITY = vec3(0.0);
    ACTIVE   = true;
}

void process() {
    vec3 box_size = vec3(
        length(EMISSION_TRANSFORM[0].xyz),
        length(EMISSION_TRANSFORM[1].xyz),
        length(EMISSION_TRANSFORM[2].xyz)
    );

    vec3 local_p = TRANSFORM[3].xyz - EMISSION_TRANSFORM[3].xyz;

	// Kill outside box — Y now centered like X and Z
	if(local_p.x < -box_size.x || local_p.x > box_size.x ||
	   local_p.y < -box_size.y  || local_p.y > box_size.y ||
	   local_p.z < -box_size.z  || local_p.z > box_size.z){
	    ACTIVE = false;
	}
	
	// UVW — remap -1..1 to 0..1 for Y too
	vec3 uvw = vec3(
	    (local_p.x + box_size.x) / (box_size.x * 2.0),
	    (local_p.y + box_size.y) / (box_size.y * 2.0),  // centered
	    (local_p.z + box_size.z) / (box_size.z * 2.0)
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