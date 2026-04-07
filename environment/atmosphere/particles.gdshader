shader_type particles;

uniform sampler3D weather : hint_default_black, repeat_disable;
uniform float wind_strength = 1.0;
uniform float min_scale = 0.2;
uniform float max_scale = 4.0;
uniform float stretch_factor = 8.0;

float rand(float seed) {
    return fract(sin(seed) * 43758.5453);
}

void start() {
    // Extract box size from EMISSION_TRANSFORM (scale of each axis)
    vec3 box_size = vec3(
        length(EMISSION_TRANSFORM[0].xyz),
        length(EMISSION_TRANSFORM[1].xyz),
        length(EMISSION_TRANSFORM[2].xyz)
    );

    // Random position in LOCAL emitter space
    vec3 local_pos = vec3(
        (rand(float(INDEX) + TIME) * 2.0 - 1.0) * box_size.x,
        rand(float(INDEX) + TIME +1.0) * box_size.y,
        (rand(float(INDEX) + TIME + 2.0) * 2.0 - 1.0) * box_size.z
    );

    // Convert to world space using EMISSION_TRANSFORM
    TRANSFORM[3].xyz = (EMISSION_TRANSFORM * vec4(local_pos, 1.0)).xyz;

    VELOCITY = vec3(0.0);
    ACTIVE = true;
}

////////////////////////////////////////////////////////////
// PROCESS: Move, sample wind, scale, rotate
////////////////////////////////////////////////////////////
void process() {
    // Recompute box size
    vec3 box_size = vec3(
        length(EMISSION_TRANSFORM[0].xyz),
        length(EMISSION_TRANSFORM[1].xyz),
        length(EMISSION_TRANSFORM[2].xyz)
    );

    // Convert particle position -> LOCAL emitter space
    mat4 inv_emission = inverse(EMISSION_TRANSFORM);
    vec3 local_p = (inv_emission * vec4(TRANSFORM[3].xyz, 1.0)).xyz;

    ////////////////////////////////////////////////////////////
    // Kill particles outside box
    ////////////////////////////////////////////////////////////
    if(local_p.x < -box_size.x || local_p.x > box_size.x ||
       local_p.y < 0.0         || local_p.y > box_size.y ||
       local_p.z < -box_size.z || local_p.z > box_size.z) {
        ACTIVE = false;
        //return;
    }

    ////////////////////////////////////////////////////////////
    // Sample wind texture (UVW in 0–1)
    ////////////////////////////////////////////////////////////
    vec3 uvw = vec3(
        (local_p.x + box_size.x) / (box_size.x * 2.0),
        local_p.y / box_size.y,
        (local_p.z + box_size.z) / (box_size.z * 2.0)
    );

    vec3 wind = texture(weather, uvw).xyz;
    float wind_speed = length(wind);

    ////////////////////////////////////////////////////////////
    // Movement
    ////////////////////////////////////////////////////////////
    VELOCITY = wind * wind_strength;
    TRANSFORM[3].xyz += VELOCITY * DELTA;
	
	vec3 dir = normalize(VELOCITY);
	
	COLOR = vec4(dir * 1.0, 1.0);

    ////////////////////////////////////////////////////////////
    // Rotation + Scaling
    ////////////////////////////////////////////////////////////
    if(wind_speed > 0.0001) {
        vec3 up = normalize(wind);

        vec3 forward = vec3(0.0, 0.0, 1.0);
        if(abs(dot(up, forward)) > 0.999)
            forward = vec3(1.0, 0.0, 0.0);

        vec3 right = normalize(cross(up, forward));
        forward = normalize(cross(right, up));

        // Normalize wind speed influence (adjust if needed)
        float t = clamp(wind_speed, 0.0, 1.0);

        // Base scale
        float base_scale = mix(min_scale, max_scale, t);

        // Stretch along wind direction
        float stretch = 1.0 + wind_speed * stretch_factor;

        // Apply rotation + non-uniform scaling
        TRANSFORM[0].xyz = right * base_scale;
        TRANSFORM[1].xyz = up * base_scale * stretch;
        TRANSFORM[2].xyz = forward * base_scale;
    } else{
        ACTIVE = false;
	}
}