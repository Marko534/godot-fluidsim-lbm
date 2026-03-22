#[compute]
#version 460 core
layout(local_size_x = 16, local_size_y = 1, local_size_z = 16) in;
#include "lbm.glsl"

layout(set = 0, binding = 6, rgba32f) uniform restrict writeonly image3D velocity_tex_3d;

layout(std430, binding = 4) buffer v { vec4 V[]; };

void main(){
    int x = int(gl_GlobalInvocationID.x);
    int y = int(gl_GlobalInvocationID.y);
    int z = int(gl_GlobalInvocationID.z);

    uint ind = (x * params.NY + y) * params.NZ + z;
    imageStore(velocity_tex_3d, ivec3(x, y, z), V[ind]);
}

// #[compute]
// #version 460 core
// layout(local_size_x = 16, local_size_y = 1, local_size_z = 16) in;
// #include "lbm.glsl"

// layout(std430, binding = 4) buffer v { vec4 V[]; };

// void main(){
//     int x = int(gl_GlobalInvocationID.x);
//     int y = int(gl_GlobalInvocationID.y);
//     int z = int(gl_GlobalInvocationID.z);

//     // TEMP: ignore V[], write a visible test pattern
//     vec4 test = vec4(
//         float(x) / float(params.NX),  // red increases along X
//         float(y) / float(params.NY),  // green increases along Y
//         float(z) / float(params.NZ),  // blue increases along Z
//         1.0
//     );
//     imageStore(velocity_tex_3d, ivec3(x, y, z), test);
// }