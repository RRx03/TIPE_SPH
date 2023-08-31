//
//  Shader.metal
//  TIPE_SPH
//
//  Created by Roman Roux on 31/08/2023.
//

#include <metal_stdlib>
#include "../Common.h"
using namespace metal;




struct VertexIn
{
    float4 position [[attribute(0)]];
    float3 normal [[attribute(1)]];
};

struct VertexOut
{
    float4 position [[position]];
    float3 normal;

};

vertex VertexOut draw(const VertexIn vertexIn [[stage_in]],
                             constant Particle *particles [[buffer(1)]],
                             constant Uniforms &uniforms [[buffer(11)]],
                             uint instanceid [[instance_id]])
{
    
    VertexOut out;
    Particle particle = particles[instanceid];
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * vertexIn.position;
    out.normal = vertexIn.normal;
    
    return out;
}

fragment float4 fragment_main(VertexOut vertexIn [[stage_in]], constant Params &params [[buffer(12)]])
{
    
    return float4(float3(1), 1);
}
