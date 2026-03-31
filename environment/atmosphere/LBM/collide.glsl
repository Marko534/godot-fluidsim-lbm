#[compute]
#version 460 core
// core

layout(local_size_x = 32, local_size_y = 1, local_size_z = 32) in;

#include "lbm15.glsl"

const float tau = 0.56;
const float dt  = 1.0;

void main(){
    const uint ind  = (gl_GlobalInvocationID.x * params.NY + gl_GlobalInvocationID.y) * params.NZ + gl_GlobalInvocationID.z;
    const float _rho = getRho(ind);
    vec3 _v          = getV(ind) / _rho;

    _v += dt * 0.0001 * c[4] / (2.0f * _rho);

    // Write directly to texture — no V[] buffer needed
    imageStore(velocity_tex_3d, ivec3(gl_GlobalInvocationID.xyz), vec4(_v, _rho));

    const float omega_plus  = 1.0 / tau;
    const float lambda      = 0.25;
    const float omega_minus = 1.0 / (lambda / (1.0/omega_plus - 0.5) + 0.5);

    float ffeq[Q];
    for(int q = 0; q < Q; q++)
        ffeq[q] = equilibrium(q, _rho, _v);

    for(int q = 0; q < Q; q++){
        float f_plus    = 0.5 * (F[ind*Q + q]    + F[ind*Q + cp[q]]);
        float f_minus   = 0.5 * (F[ind*Q + q]    - F[ind*Q + cp[q]]);
        float feq_plus  = 0.5 * (ffeq[q]          + ffeq[cp[q]]);
        float feq_minus = 0.5 * (ffeq[q]          - ffeq[cp[q]]);

        FPROP[ind*Q + q] = F[ind*Q + q]
            - omega_plus  * (f_plus  - feq_plus)
            - omega_minus * (f_minus - feq_minus);

        if(B[ind] > 0.0)
            FPROP[ind*Q + q] = equilibrium(q, 1.0, vec3(0));
    }
}