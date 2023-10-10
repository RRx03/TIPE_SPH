#include <metal_stdlib>

#include "../Common.h"
using namespace metal;

#define groundCollisions true


struct VertexIn
{
    float4 position [[attribute(0)]];
    float3 normal [[attribute(1)]];
};

struct VertexOut
{
    float4 position [[position]];
    float3 velocity;
    float3 normal;
};

float Weight(float q, float hConst3)
{
//    return 315 * pow((hConst2 - pow(dist, 2)), 3) / (64 * M_PI_F * hConst9);
    float alpha = 1/(4*M_PI_F*hConst3);
    if (q >= 0 && q < 1){
        return alpha*(pow((2-q), 3)-4*pow((1-q), 3));
    }
    else if (q >= 1 && q < 2){
        return alpha*(pow(2-q, 3));
        
    }
        return 0;

}

float Weight2(float x, float hConst)
{
    return (2/(3*hConst))*exp(-(x*x)/(2*pow(0.59*hConst, 2)));
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
    out.velocity = particle.velocity;

    return out;
}

fragment float4 Fragment(VertexOut vertexIn [[stage_in]], constant Params &params [[buffer(12)]])
{

#define minLighting 0.1
#define offset 1
#define radius 1
#define mag 10



    
    float velScale = length(vertexIn.velocity)*mag;
    float r = (M_PI_F/2+atan(velScale-offset-radius))*2/M_PI_F;
    float g = max(0.0, 1-pow(velScale-offset, 2));
    float b = (M_PI_F/2-atan(velScale-offset+radius))*2/M_PI_F;
    
    
    

    
    
    float3 light = normalize(float3(0, -1, 1));
    float iso = max(minLighting, dot(vertexIn.normal, -light));
    float3 color;
    color = float3(r, g, b);
    return float4(color * iso, 1);
}


int3 coordsFromId (int ID, int3 cellStruct){
    int z = int(ID/(cellStruct.x*cellStruct.y));
    int y = int((ID-z)/(cellStruct.x));
    int x = int((ID-z-y));
    return int3(0, ID/10, 0);
    return int3(x, y, z);

    
}
kernel void CellUpdate (device Particle *particles [[buffer(1)]],
                        device int *lookupTable [[buffer(2)]],
                        device int *indices [[buffer(3)]],
                        device int *startIndices [[buffer(4)]],
                        constant Uniforms &uniforms [[buffer(11)]],
                        uint id [[thread_position_in_grid]])
{
    Particle particle = particles[id];
    int3 cellCoords = int3(particle.position/float3(uniforms.cellStruct));
    int cellID = cellCoords.x + uniforms.cellStruct.x*cellCoords.y + uniforms.cellStruct.x+uniforms.cellStruct.y*cellCoords.z;
    indices[id] = id;
    lookupTable[id] = cellID;
    
    
    
}


kernel void updateParticles(device Particle *particles [[buffer(1)]],
                            device int *lookupTable [[buffer(2)]],
                            device int *indices [[buffer(3)]],
                            device int *startIndices [[buffer(4)]],
                            constant Uniforms &uniforms [[buffer(11)]],
                            uint id [[thread_position_in_grid]])
{
    
    
    Particle particle = particles[id];
    
    particle.forces = float3(0, -uniforms.gravity * uniforms.particleMass, 0);
    particle.rho = 0;
    
    float updateDeltaTime = uniforms.deltaTime;
    
    for (uint otherParticleID = 0; otherParticleID < uint(uniforms.particleCount); otherParticleID++){
        if(otherParticleID == id){
            continue;
        }
        
        
        Particle otherParticle = particles[otherParticleID];
        float3 diff = otherParticle.position - particle.position; //Continous collisions (text for position + Vel (= Verlet vel) etc etc ad test for distance ...)
        float dist = length(diff);
        if(dist != 0){
            float3 Ndiff = normalize(diff);
            if(dist < uniforms.particleRadius*2){
                particle.position += -Ndiff*(uniforms.particleRadius*2-dist)/2; //this would allow bouncing coefficient to get introduced
                otherParticle.position += Ndiff*(uniforms.particleRadius*2-dist)/2;
                particles[otherParticleID] = otherParticle;
            }
        }
        if(dist < uniforms.hConst){
            particle.rho += uniforms.particleMass*Weight(dist/uniforms.hConst, uniforms.hConst3);
        }
    }
    
    
    
    
    
    particle.velocity = particle.position - particle.oldPosition;
    particle.acceleration = particle.forces / uniforms.particleMass;
    particle.oldPosition = particle.position;
    particle.position += (particle.velocity)*uniforms.globalFriction + particle.acceleration * updateDeltaTime * updateDeltaTime;
    
    
    if(particle.position.y <= uniforms.particleRadius && groundCollisions){
        particle.position.y = uniforms.particleRadius;
    }
    if(particle.position.x < uniforms.containerPosition.x - uniforms.containerSize.x / 2 + uniforms.particleRadius){
        particle.position.x = uniforms.containerPosition.x - uniforms.containerSize.x / 2 + uniforms.particleRadius;
        
    }
    else if(particle.position.x > uniforms.containerPosition.x + uniforms.containerSize.x / 2 - uniforms.particleRadius){
        particle.position.x = uniforms.containerPosition.x + uniforms.containerSize.x / 2 - uniforms.particleRadius;
        
    }
    if(particle.position.z < uniforms.containerPosition.z - uniforms.containerSize.z / 2 + uniforms.particleRadius){
        particle.position.z = uniforms.containerPosition.z - uniforms.containerSize.z / 2 + uniforms.particleRadius;
        
    }
    else if(particle.position.z > uniforms.containerPosition.z + uniforms.containerSize.z / 2 - uniforms.particleRadius){
        particle.position.z = uniforms.containerPosition.z + uniforms.containerSize.z / 2 - uniforms.particleRadius;
        
    }
    if(particle.position.y < uniforms.containerPosition.y - uniforms.containerSize.y / 2 + uniforms.particleRadius){
        particle.position.y = uniforms.containerPosition.y - uniforms.containerSize.y / 2 + uniforms.particleRadius;
        
    }
    else if(particle.position.y > uniforms.containerPosition.y + uniforms.containerSize.y / 2 - uniforms.particleRadius){
        particle.position.y = uniforms.containerPosition.y + uniforms.containerSize.y / 2 - uniforms.particleRadius;
        
    }
    particle.velocity = particle.position - particle.oldPosition;
    
//    particle.position = float3(coordsFromId(lookupTable[id], uniforms.cellStruct));
    particles[id] = particle;
}

