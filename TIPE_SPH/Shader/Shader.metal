#include <metal_stdlib>
#include "../Common.h"
using namespace metal;

#define applyBorderCollision true
#define groundCollisions true

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
    float3 light = float3(0, -1, 1);
    float iso = max(minLighting, dot(vertexIn.normal, -light));
    return float4(float3(1) * iso, 1);
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
            float3 Ndiff = normalize(diff);
            if(dist < uniforms.particleRadius*2){
                particle.forces += (dot(particle.forces,Ndiff) > 0) ? -Ndiff*dot(particle.forces,Ndiff) : 0;
                particle.forces += (dot(otherParticle.forces,Ndiff) < 0) ? Ndiff*dot(otherParticle.forces,Ndiff) : 0;
                particle.velocity += -Ndiff*dot(particle.velocity,Ndiff) + (-Ndiff*dot(otherParticle.velocity, -Ndiff))*uniforms.particleBouncingCoefficient;
                particle.position += Ndiff*(dist-2*uniforms.particleRadius);
            }
        }
    
    float3 positionShifter = float3(0, 0, 0);
    float updateDeltaTime = uniforms.deltaTime;

    particle.acceleration = particle.forces / uniforms.particleMass;
    particle.velocity += particle.acceleration * uniforms.deltaTime;

    if (particle.position.y + particle.velocity.y * updateDeltaTime <= uniforms.particleRadius && groundCollisions)
    {
        float collisionTime = (uniforms.particleRadius - particle.position.y) / particle.velocity.y;
        particle.position += (collisionTime)*particle.velocity;
        particle.velocity.y *= -uniforms.particleBouncingCoefficient;
        particle.position += (updateDeltaTime - collisionTime) * particle.velocity;
        positionShifter -= (updateDeltaTime)*particle.velocity;
        updateDeltaTime -= collisionTime;
    }
    if (particle.position.x + particle.velocity.x * updateDeltaTime <= uniforms.containerPosition.x - uniforms.containerSize.x / 2 + uniforms.particleRadius && applyBorderCollision)
    {
        float collisionTime = (uniforms.containerPosition.x - uniforms.containerSize.x / 2 + uniforms.particleRadius - particle.position.x) / particle.velocity.x;
        particle.position += (collisionTime)*particle.velocity;
        particle.velocity.x *= -uniforms.particleBouncingCoefficient;
        particle.position += (updateDeltaTime - collisionTime) * particle.velocity;
        positionShifter -= (updateDeltaTime)*particle.velocity;
        updateDeltaTime -= collisionTime;
    }
    else if (particle.position.x + particle.velocity.x * updateDeltaTime >= uniforms.containerPosition.x + uniforms.containerSize.x / 2 - uniforms.particleRadius && applyBorderCollision)
    {
        float collisionTime = (uniforms.containerPosition.x + uniforms.containerSize.x / 2 - uniforms.particleRadius - particle.position.x) / particle.velocity.x;
        particle.position += (collisionTime)*particle.velocity;
        particle.velocity.x *= -uniforms.particleBouncingCoefficient;
        particle.position += (updateDeltaTime - collisionTime) * particle.velocity;
        positionShifter -= (updateDeltaTime)*particle.velocity;
        updateDeltaTime -= collisionTime;
    }
    if (particle.position.z + particle.velocity.z * updateDeltaTime <= uniforms.containerPosition.z - uniforms.containerSize.z / 2 + uniforms.particleRadius && applyBorderCollision)
    {
        float collisionTime = (uniforms.containerPosition.z - uniforms.containerSize.z / 2 + uniforms.particleRadius - particle.position.z) / particle.velocity.z;
        particle.position += (collisionTime)*particle.velocity;
        particle.velocity.z *= -uniforms.particleBouncingCoefficient;
        particle.position += (updateDeltaTime - collisionTime) * particle.velocity;
        positionShifter -= (updateDeltaTime)*particle.velocity;
        updateDeltaTime -= collisionTime;
    }
    else if (particle.position.z + particle.velocity.z * updateDeltaTime >= uniforms.containerPosition.z + uniforms.containerSize.z / 2 - uniforms.particleRadius && applyBorderCollision)
    {
        float collisionTime = (uniforms.containerPosition.z + uniforms.containerSize.z / 2 - uniforms.particleRadius - particle.position.z) / particle.velocity.z;
        particle.position += (collisionTime)*particle.velocity;
        particle.velocity.z *= -uniforms.particleBouncingCoefficient;
        particle.position += (updateDeltaTime - collisionTime) * particle.velocity;
        positionShifter -= (updateDeltaTime)*particle.velocity;
        updateDeltaTime -= collisionTime;
    }

    particle.position += positionShifter;
    particle.position += particle.velocity * uniforms.deltaTime;
    
    
    if(particle.position.y < 0 && groundCollisions){
        particle.position.y += uniforms.particleRadius;
        particle.velocity = float3(0);

    }
    if(particle.position.x < uniforms.containerPosition.x - uniforms.containerSize.x / 2 && applyBorderCollision){
        particle.position.x += uniforms.particleRadius;
        particle.velocity = float3(0);

    }
    else if(particle.position.x > uniforms.containerPosition.x + uniforms.containerSize.x / 2 && applyBorderCollision){
        particle.position.x += uniforms.particleRadius;
        particle.velocity = float3(0);

    }
    if(particle.position.z < uniforms.containerPosition.z - uniforms.containerSize.z / 2 && applyBorderCollision){
        particle.position.z += uniforms.particleRadius;
        particle.velocity = float3(0);

    }
    else if(particle.position.z > uniforms.containerPosition.z + uniforms.containerSize.z / 2 && applyBorderCollision){
        particle.position.z += uniforms.particleRadius;
        particle.velocity = float3(0);

    }
    particles[id] = particle;
}
