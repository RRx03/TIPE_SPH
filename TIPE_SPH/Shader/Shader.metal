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

vertex VertexOut Vertex(const VertexIn vertexIn [[stage_in]])
{
    
    VertexOut out;
    out.position = vertexIn.position;
    out.normal = vertexIn.normal;
    return out;
}

fragment float4 Fragment(VertexOut vertexIn [[stage_in]])
{
    
    return float4(1);
}
