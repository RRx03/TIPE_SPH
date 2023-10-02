#include <metal_stdlib>

#include "../Common.h"
using namespace metal;

#define groundCollisions true
#define applyCollisions false


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

float Weight(float dist, float hConst2, float hConst9)
{

    return 315 * pow((hConst2 - pow(dist, 2)), 3) / (64 * M_PI_F * hConst9);
}

matrix_float4x4 translationMatrix(float3 translation)
{
    return matrix_float4x4(float4(1.0, 0.0, 0., 0.), float4(0., 1., 0., 0.), float4(0., 0., 1., 0.), float4(translation.x, translation.y, translation.z, 1.));
}

vertex VertexOut Vertex(const VertexIn vertexIn [[stage_in]],
                        constant Particle *particles [[buffer(1)]],
                        constant Uniforms &uniforms [[buffer(11)]],
                        uint instanceid [[instance_id]])
{

    VertexOut out;
    Particle particle = particles[instanceid];
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * translationMatrix(particle.position) * vertexIn.position;
    out.normal = vertexIn.normal;

    return out;
}

fragment float4 Fragment(VertexOut vertexIn [[stage_in]], constant Params &params [[buffer(12)]])
{

#define minLighting 0.1
    float3 light = normalize(float3(0, -1, 1));
    
    float iso = max(minLighting, dot(vertexIn.normal, -light));
    float3 color = float3(0.25, 0.87, 0.82);
    color = float3(1);
    return float4(color * iso, 1);
}


kernel void updateParticles(device Particle *particles [[buffer(1)]], constant Uniforms &uniforms [[buffer(11)]], uint id [[thread_position_in_grid]])
{
    Particle particle = particles[id];

    particle.forces = float3(0, -uniforms.gravity * uniforms.particleMass, 0);
    
    
    for (uint otherParticleID = 0; otherParticleID < uint(uniforms.particleCount); otherParticleID++){
        if(otherParticleID == id){
            continue;
        }

        
        Particle otherParticle = particles[otherParticleID];
        float3 diff = otherParticle.position - particle.position;
        float dist = length(diff);
        if(dist != 0){
            float3 Ndiff = normalize(diff);
            if(dist < uniforms.particleRadius*2){
                particle.position += -Ndiff*(uniforms.particleRadius*2-dist)/2;
                otherParticle.position += Ndiff*(uniforms.particleRadius*2-dist)/2;
                particles[otherParticleID] = otherParticle;
            }
            
        }
    }
    
    
    
    
    if (particle.position.y <= uniforms.particleRadius && groundCollisions)
    {
        particle.position.y = uniforms.particleRadius;
    }
    if (particle.position.x <= uniforms.containerPosition.x - uniforms.containerSize.x / 2 + uniforms.particleRadius && applyCollisions)
    {
        particle.position.x = uniforms.containerPosition.x - uniforms.containerSize.x / 2 + uniforms.particleRadius;
    }
    else if (particle.position.x >= uniforms.containerPosition.x + uniforms.containerSize.x / 2 - uniforms.particleRadius && applyCollisions)
    {
        particle.position.x = uniforms.containerPosition.x + uniforms.containerSize.x / 2 - uniforms.particleRadius;
    }
    if (particle.position.z <= uniforms.containerPosition.z - uniforms.containerSize.z / 2 + uniforms.particleRadius && applyCollisions)
    {
        particle.position.z = uniforms.containerPosition.z - uniforms.containerSize.z / 2 + uniforms.particleRadius;
    }
    else if (particle.position.z >= uniforms.containerPosition.z + uniforms.containerSize.z / 2 - uniforms.particleRadius && applyCollisions)
    {
        particle.position.z = uniforms.containerPosition.z + uniforms.containerSize.z / 2 - uniforms.particleRadius;
    }
    
    
    
    particle.acceleration = particle.forces / uniforms.particleMass;
    
    particle.velocity = particle.position - particle.oldPosition;
    particle.oldPosition = particle.position;
    particle.position += particle.velocity + particle.acceleration * uniforms.deltaTime * uniforms.deltaTime;

    particles[id] = particle;
}
