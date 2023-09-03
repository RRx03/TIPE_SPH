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
    float iso = max(minLighting, dot(vertexIn.normal, -light));
    return float4(float3(1)*iso, 1);
}


kernel void updateParticles(device Particle *particles [[buffer(1)]], constant Uniforms &uniforms [[buffer(11)]],  uint id [[thread_position_in_grid]]){
    Particle particle = particles[id];
    
    particle.acceleration = float3(0, 0, 0);
    
    for (uint otherParticleID = 0; otherParticleID < uint(uniforms.particleCount); otherParticleID++){
        
        if(otherParticleID == id){
            continue;
        }
        
        Particle otherParticle = particles[otherParticleID];
        float3 diff = otherParticle.position - particle.position;
        float dist = length(diff);
        if(dist < uniforms.hConst){
            particle.velocity += -normalize(diff)*dot(particle.velocity,diff) + normalize(diff)*dot(otherParticle.velocity, diff);
        }
        
    }
    
    
    
    
    
    
    particle.acceleration += float3(0, -9.81, 0);
    particle.velocity += particle.acceleration*uniforms.deltaTime;
    particle.position += particle.velocity*uniforms.deltaTime;
    
    if(particle.position.x < uniforms.containerPosition.x){
        particle.position.x = uniforms.containerPosition.x;
        particle.velocity.x *= -uniforms.particleBouncingCoefficient;
        
    }
    else if(particle.position.x > uniforms.containerPosition.x+uniforms.containerSize.x){
        particle.position.x = uniforms.containerPosition.x+uniforms.containerSize.x;
        particle.velocity.x *= -uniforms.particleBouncingCoefficient;
        
    }
    if(particle.position.y < uniforms.containerPosition.y){
        particle.position.y = uniforms.containerPosition.y;
        particle.velocity.y *= -uniforms.particleBouncingCoefficient;
        
    }
    else if(particle.position.y > uniforms.containerPosition.y+uniforms.containerSize.y){
        particle.position.y = uniforms.containerPosition.y+uniforms.containerSize.y;
        particle.velocity.y *= -uniforms.particleBouncingCoefficient;
        
    }
    if(particle.position.z < uniforms.containerPosition.z){
        particle.position.z = uniforms.containerPosition.z;
        particle.velocity.z *= -uniforms.particleBouncingCoefficient;
        
    }
    else if(particle.position.z > uniforms.containerPosition.z+uniforms.containerSize.z){
        particle.position.z = uniforms.containerPosition.z+uniforms.containerSize.z;
        particle.velocity.z *= -uniforms.particleBouncingCoefficient;
        
    }
    
    particles[id] = particle;
}

float Weight(float dist, float hConst2, float hConst9){
    
    return 315*pow((hConst2-pow(dist, 2)), 3)/(64*M_PI_F*hConst9);
    
}
