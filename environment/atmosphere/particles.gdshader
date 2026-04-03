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
    TRANSFORM[3].x = rand(float(INDEX) + TIME) * 2.0 - 1.0;
    TRANSFORM[3].y = rand(float(INDEX) + TIME + 1.0);
    TRANSFORM[3].z = rand(float(INDEX) + TIME + 2.0) * 2.0 - 1.0;
    VELOCITY       = vec3(0.0);
    ACTIVE         = true;
}

void process() {
    vec3 p = TRANSFORM[3].xyz;
    if(p.x < -1.0 || p.x > 1.0
    || p.y < 0.0  || p.y > 0.5
    || p.z < -1.0 || p.z > 1.0){
        ACTIVE = false;
    }

    vec3 uvw  = vec3(
        (TRANSFORM[3].x + 1.0) / 2.0,
        (TRANSFORM[3].y + 0.5),
        (TRANSFORM[3].z + 1.0) / 2.0
    );
    vec3 wind         = texture(weather, uvw).xyz;
    float wind_speed  = length(wind);
    VELOCITY          = wind * wind_strength;
    TRANSFORM[3].xyz += VELOCITY * DELTA;

    // Rotate arrow to point in wind direction
    if(wind_speed > 0.0001){
        vec3 up      = normalize(wind);
        vec3 forward = vec3(0.0, 0.0, 1.0);
        if(abs(dot(up, forward)) > 0.999)
            forward  = vec3(1.0, 0.0, 0.0);
        vec3 right   = normalize(cross(up, forward));
        forward      = normalize(cross(right, up));
        
        // Base scale from wind speed
        float base_scale = mix(min_scale, max_scale, clamp(wind_speed, 0.0, 1.0));
        
        // Stretch more in wind direction (Y axis)
        float stretch = 1.0 + wind_speed * stretch_factor;
        
        TRANSFORM[0].xyz = right * base_scale;           // X axis (perpendicular)
        TRANSFORM[1].xyz = up * base_scale * stretch;    // Y axis (wind direction)
        TRANSFORM[2].xyz = forward * base_scale;         // Z axis (perpendicular)
    }
}