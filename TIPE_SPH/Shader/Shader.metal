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

vertex VertexOut Vertex(const VertexIn vertexIn [[stage_in]], constant Uniforms &uniforms [[buffer(11)]])
{
    
    VertexOut out;
    out.position =  uniforms.projectionMatrix * uniforms.viewMatrix * vertexIn.position;
    out.normal = vertexIn.normal;
    return out;
}

fragment float4 Fragment(VertexOut vertexIn [[stage_in]], constant Params &params [[buffer(12)]])
{
    
#define minLighting 0.1
    float3 light = float3(0, -1, -1);
    float iso = max(minLighting, dot(vertexIn.normal, -light));
    return float4(float3(1)*iso, 1);
}
