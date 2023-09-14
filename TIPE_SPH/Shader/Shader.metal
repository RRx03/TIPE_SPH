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

matrix_float4x4 translationMatrix(float3 translation){
    return matrix_float4x4(float4(1.0, 0.0, 0., 0.), float4(0., 1., 0., 0.), float4(0., 0., 1., 0.),  float4(translation.x, translation.y, translation.z, 1.));
    
}

vertex VertexOut Vertex(const VertexIn vertexIn [[stage_in]],
                        constant Particle *particles [[buffer(1)]],
                        constant Uniforms &uniforms [[buffer(11)]],
                        uint instanceid [[instance_id]])
{
    VertexOut out;
    Particle particle = particles[instanceid];
    out.position =  uniforms.projectionMatrix * uniforms.viewMatrix * translationMatrix(particle.position) * vertexIn.position;
    out.normal = vertexIn.normal;
    
    return out;
}

fragment float4 Fragment(VertexOut vertexIn [[stage_in]], constant Params &params [[buffer(12)]])
{
#define minLighting 0.1
    float3 light = float3(0, -1, 1);
    float iso = 1;
    iso = max(minLighting, dot(vertexIn.normal, -light));
    return float4(float3(1)*iso, 1);
}

float W(float r, float h, float h2){
    return pow((1/(h*sqrt(M_PI_F))), 3)*exp(-(pow(r, 2)/h2));
}

float3 clamp(float3 x, float maxVal){
    float mag = length(x);
    float diff = maxVal/mag;
    return (diff < 1) ? normalize(x)*maxVal : x;
}

kernel void updateParticles(device Particle *particles [[buffer(1)]], constant Uniforms &uniforms [[buffer(11)]],  uint id
                            [[thread_position_in_grid]]){
    
#define applyBorderCollision true
    Particle particle = particles[id];
    
    particle.acceleration = float3(0, 0, 0);
    particle.acceleration += float3(0, -9.81*uniforms.particleMass, 0);
    
    for (uint otherParticleID = 0; otherParticleID < uint(uniforms.particleCount); otherParticleID++){
        
        if(otherParticleID == id){
            continue;
        }
        
        Particle otherParticle = particles[otherParticleID];
        float3 diff = otherParticle.position - particle.position;
        float dist = length(diff);
        
        if(dist < uniforms.particleRadius*2){
            
        }
        
    }
    
    //MARK: - Border Collisions
    if(particle.position.x < uniforms.containerPosition.x && applyBorderCollision){
        particle.position.x = uniforms.containerPosition.x;
        particle.velocity.x *= -uniforms.particleBouncingCoefficient;
    }
    else if(particle.position.x > uniforms.containerPosition.x+uniforms.containerSize.x && applyBorderCollision){
        particle.position.x = uniforms.containerPosition.x+uniforms.containerSize.x;
        particle.velocity.x *= -uniforms.particleBouncingCoefficient;
    }
    if(particle.position.z < uniforms.containerPosition.z && applyBorderCollision){
        particle.position.z = uniforms.containerPosition.z;
        particle.velocity.z *= -uniforms.particleBouncingCoefficient;
    }
    else if(particle.position.z > uniforms.containerPosition.z+uniforms.containerSize.z && applyBorderCollision){
        particle.position.z = uniforms.containerPosition.z+uniforms.containerSize.z;
        particle.velocity.z *= -uniforms.particleBouncingCoefficient;
    }
    if(particle.position.y < uniforms.containerPosition.y){
        particle.position.y = uniforms.containerPosition.y;
        particle.velocity.y *= -uniforms.particleBouncingCoefficient;
    }
    else if(particle.position.y > uniforms.containerPosition.y+uniforms.containerSize.y){
        particle.position.y = uniforms.containerPosition.y+uniforms.containerSize.y;
        particle.velocity.y *= -uniforms.particleBouncingCoefficient;
    }
    
    
    
    particle.velocity += particle.acceleration*uniforms.deltaTime/uniforms.particleMass;
    particle.velocity = clamp(particle.velocity, uniforms.vmax);
    particle.position += particle.velocity*uniforms.deltaTime;
    
    particles[id] = particle;
}


