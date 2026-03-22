shader_type particles;

//uniform float gravity = -9.8;
float rand(float seed) {
    return fract(sin(seed) * 43758.5453);
}

void start() {
    TRANSFORM[3].x = rand(float(INDEX) + TIME) * 64.0 - 32.0;
    TRANSFORM[3].y = rand(float(INDEX) + TIME + 1.0) * 32.0 - 16.0;
    TRANSFORM[3].z = rand(float(INDEX) + TIME + 2.0) * 64.0 - 32.0;
    VELOCITY       = vec3(0.0);
}
void process() {
    //VELOCITY.y       += gravity * DELTA;
    //TRANSFORM[3].xyz += VELOCITY * DELTA;
}