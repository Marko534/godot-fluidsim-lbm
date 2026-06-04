#[compute]
#version 460 core

// layout(local_size_x = 32, local_size_y = 1, local_size_z = 32) in;
layout(local_size_x = 16, local_size_y = 2, local_size_z = 16) in;

// Change to change alg
// #include "lbm15.glsl"
// #include "lbm19.glsl"
#include "lbm27.glsl"

void main(){
    uint ind = (gl_GlobalInvocationID.x * params.NY + gl_GlobalInvocationID.y) * params.NZ + gl_GlobalInvocationID.z;

    for(int q = 0; q < Q; q++){
        F[ind*Q + q] = equilibrium(q, 1.0, force);
        if(B[ind] > 0)
            F[ind*Q + q] = equilibrium(q, 1.0, vec3(0));
    }

    // float _rho = getRho(ind);
    // vec3  _v   = getV(ind) / _rho;

    float _rho;
    vec3  _v;
    float f_cache[Q];
    getRhoV(ind, _rho, _v, f_cache);

    imageStore(velocity_tex_3d, ivec3(gl_GlobalInvocationID.xyz), vec4(_v, _rho));
}