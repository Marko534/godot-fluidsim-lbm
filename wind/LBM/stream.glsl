#[compute]
#version 460 core

layout(local_size_x = 16, local_size_y = 1, local_size_z = 16) in;

#include "lbm.glsl"

layout (std430, binding = 3) buffer rho {
  float RHO[];
};

void main(){

  const uint ind = (gl_GlobalInvocationID.x*params.NY + gl_GlobalInvocationID.y)*params.NZ + gl_GlobalInvocationID.z;

  for(int q = 0; q < Q; q++){

    ivec3 n = ivec3(gl_GlobalInvocationID.xyz) + c[q];
    if(n.x < 0 || n.x >= params.NX) continue;
    if(n.y < 0 || n.y >= params.NY) continue;
    if(n.z < 0 || n.z >= params.NZ) continue;

    const int nind = (n.x*params.NY + n.y)*params.NZ + n.z;
    F[nind*Q+q] = FPROP[ind*Q+q];

  }




  // Optional: Driving Force (Wetnode Approach)

  if( gl_GlobalInvocationID.y == params.NY-1
  || gl_GlobalInvocationID.x == 0
  || gl_GlobalInvocationID.x == params.NX-1
  || gl_GlobalInvocationID.z == 0
  || gl_GlobalInvocationID.z == params.NZ-1
  ){

    for(int q = 0; q < Q; q++)
      F[ind*Q + q] = equilibrium(q, 1.0, force);

  }

}
