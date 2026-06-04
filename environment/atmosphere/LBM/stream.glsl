#[compute]
#version 460 core

// layout(local_size_x = 32, local_size_y = 1, local_size_z = 32) in;
layout(local_size_x = 16, local_size_y = 2, local_size_z = 16) in;

// Change to change alg
// #include "lbm15.glsl"
// #include "lbm19.glsl"
#include "lbm27.glsl"

void main(){
    const uint ind = (gl_GlobalInvocationID.x * params.NY + gl_GlobalInvocationID.y) * params.NZ + gl_GlobalInvocationID.z;

    // Boundary cells — small minority, apply wetnode force and exit
    if(gl_GlobalInvocationID.y == params.NY - 1
    || gl_GlobalInvocationID.x == 0
    || gl_GlobalInvocationID.x == params.NX - 1
    || gl_GlobalInvocationID.z == 0
    || gl_GlobalInvocationID.z == params.NZ - 1){
        for(int q = 0; q < Q; q++)
            F[ind*Q + q] = equilibrium(q, 1.0, force);
        return;
    }

    // Inner cells — vast majority, no bounds check needed
    for(int q = 0; q < Q; q++){
        ivec3 n    = ivec3(gl_GlobalInvocationID.xyz) + c[q];
        int   nind = (n.x * params.NY + n.y) * params.NZ + n.z;
        F[nind*Q + q] = FPROP[ind*Q + q];
    }
}