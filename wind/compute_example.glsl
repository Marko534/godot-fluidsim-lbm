#[compute]
#version 430

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, rgba32f) uniform restrict writeonly image2D output_tex;

layout(set = 0, binding = 1) uniform TimeBuffer {
    float time;
} time_buf;

void main() {
    ivec2 coords = ivec2(gl_GlobalInvocationID.xy);
    float value = sin(float(coords.x) * 0.1 + time_buf.time) * cos(float(coords.y) * 0.1 + time_buf.time);
    imageStore(output_tex, coords, vec4(value, 0.0, 0.0, 1.0));
}