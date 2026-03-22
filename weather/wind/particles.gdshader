shader_type particles;

uniform sampler3D weather;
uniform float wind_strength = 5.0;

float rand(float seed) {
    return fract(sin(seed) * 43758.5453);
}

void start() {
    TRANSFORM[3].x = rand(float(INDEX) + TIME) * 64.0 - 32.0;
    TRANSFORM[3].y = rand(float(INDEX) + TIME + 1.0) * 32.0 - 16.0;
    TRANSFORM[3].z = rand(float(INDEX) + TIME + 2.0) * 64.0 - 32.0;
    VELOCITY       = vec3(0.0);
    ACTIVE         = true;
}

void process() {
    // Convert position to 0..1 UVW
    vec3 uvw = vec3(
        (TRANSFORM[3].x + 32.0) / 64.0,
        (TRANSFORM[3].y + 16.0) / 32.0,
        (TRANSFORM[3].z + 32.0) / 64.0
    );

    vec3 wind         = texture(weather, uvw).xyz;
    VELOCITY          = wind * wind_strength;
    TRANSFORM[3].xyz += VELOCITY * DELTA;

    // Kill outside box
    vec3 p = TRANSFORM[3].xyz;
    if(p.x < -32.0 || p.x > 32.0
    || p.y < -16.0 || p.y > 16.0
    || p.z < -32.0 || p.z > 32.0){
        ACTIVE = false;
    }
}