#include <metal_stdlib>
#include <metal_atomic>
#include "../Common.h"
using namespace metal;

#define groundCollisions false
#define offset 1
#define radius 1
#define mag 10

struct VertexIn
{
    float4 position [[attribute(0)]];
    float3 normal [[attribute(1)]];
};

struct VertexOut
{
    float4 position [[position]];
    float3 velocity;
    float3 color;
    float3 normal;
};

constant const int3 NeighB[27] = {
    int3(-1, -1, -1),
    int3(0, -1, -1),
    int3(1, -1, -1),
    int3(-1, -1, 0),
    int3(0, -1, 0),
    int3(1, -1, 0),
    int3(-1, -1, 1),
    int3(0, -1, 1),
    int3(1, -1, 1),
    int3(-1, 0, -1),
    int3(0, 0, -1),
    int3(1, 0, -1),
    int3(-1, 0, 0),
    int3(0, 0, 0),
    int3(1, 0, 0),
    int3(-1, 0, 1),
    int3(0, 0, 1),
    int3(1, 0, 1),
    int3(-1, 1, -1),
    int3(0, 1, -1),
    int3(1, 1, -1),
    int3(-1, 1, 0),
    int3(0, 1, 0),
    int3(1, 1, 0),
    int3(-1, 1, 1),
    int3(0, 1, 1),
    int3(1, 1, 1),
    
    
};


int3 CellCoords(float3 pos, float CELL_SIZE){
    return int3(pos/CELL_SIZE);
}
uint hash(int3 CellCoords, uint tableSize){
    
    int h = (CellCoords.x*92837111)^(CellCoords.y*689287499)^(CellCoords.z*283923481);
    return uint(abs(h) % tableSize);

}

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
    out.color = particle.color;

    return out;
}

fragment float4 Fragment(VertexOut vertexIn [[stage_in]], constant Params &params [[buffer(12)]])
{

#define minLighting 0.1

    float3 light = normalize(float3(0, -1, 1));
    float iso = max(minLighting, dot(vertexIn.normal, -light));
    float3 color;
    color = vertexIn.color;

    return float4(color * iso, 1);
}

kernel void initTable(constant Particle *particles [[buffer(1)]],
                      device atomic_uint &table [[buffer(2)]],
                      constant Uniforms &uniforms [[buffer(11)]],
                      uint particleID [[thread_position_in_grid]])
{
    int3 cellCoords = CellCoords(particles[particleID].position, uniforms.cellSIZE);
    uint hashValue = hash(cellCoords, uniforms.particleCount);
    atomic_fetch_add_explicit(&table+hashValue, 1, memory_order_relaxed);
}


kernel void assignDenseTable(constant Particle *particles [[buffer(1)]],
                             device atomic_uint &table [[buffer(2)]],
                             device atomic_uint &denseTable [[buffer(3)]],
                             constant Uniforms &uniforms [[buffer(11)]],
                             uint particleID [[thread_position_in_grid]])
{
    int3 cellCoords = CellCoords(particles[particleID].position, uniforms.cellSIZE);
    uint hashValue = hash(cellCoords, uniforms.particleCount);
        
    uint id = atomic_fetch_add_explicit(&table+hashValue, -1, memory_order_relaxed);
    id -= 1;

    atomic_fetch_add_explicit(&denseTable+id, particleID, memory_order_relaxed);
}

kernel void updateParticles(device Particle *particles [[buffer(1)]],
                            device uint *table [[buffer(2)]],
                            device uint *denseTable [[buffer(3)]],
                            constant StartIndexCount *startIndex [[buffer(4)]],
                            constant Uniforms &uniforms [[buffer(11)]],
                            uint id [[thread_position_in_grid]])
{
    
    float updateDeltaTime = uniforms.deltaTime/uniforms.subSteps;
    
    for(int substep = 0; substep<uniforms.subSteps; substep++){ //Improve Stability
        
        Particle particle = particles[id];
        
        int3 cellCoords = CellCoords(particles[id].position, uniforms.cellSIZE);
        
        particle.forces = float3(0, -uniforms.gravity * uniforms.particleMass, 0);
        float3 nextPosition = particle.position;
        
        
        uint NeighBCells[27];
        
        for (int i = 0; i < 27; i++){
            int3 NeighBCellCoords = cellCoords + NeighB[i];
            NeighBCells[i] = hash(NeighBCellCoords, uniforms.particleCount);
            int index = startIndex[NeighBCells[i]].startIndex;
            int neighBCount = startIndex[NeighBCells[i]].Count;
            
            if (index < uniforms.particleCount){
                
                for(int i = 0; i < neighBCount; i++){
                    if (denseTable[index+i] != id){
                        
                        Particle otherParticle = particles[denseTable[index+i]];
                        
                        float3 diff = otherParticle.position - particle.position;
                        float dist = length(diff);
                        
                        if(dist != 0){
                            float3 Ndiff = normalize(diff);
                            if(dist < uniforms.particleRadius*2){
                                nextPosition += -Ndiff*(uniforms.particleRadius*2-dist)/2;
                                otherParticle.position += Ndiff*(uniforms.particleRadius*2-dist)/2;
                                particles[denseTable[index+i]] = otherParticle;
                            }
                        }
                        if(dist < uniforms.hConst){
                            particle.rho += uniforms.particleMass*Weight(dist/uniforms.hConst, uniforms.hConst3);
                        }
                    }
                }
            }
        }
        particle.position = nextPosition;
        particle.velocity = particle.position - particle.oldPosition;
        particle.acceleration = particle.forces / uniforms.particleMass;
        particle.oldPosition = particle.position;
        particle.position += particle.velocity + particle.acceleration * updateDeltaTime * updateDeltaTime;
        
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
        float velScale = length(particle.velocity)*mag;
        float r = (M_PI_F/2+atan(velScale-offset-radius))*2/M_PI_F;
        float g = max(0.0, 1-pow(velScale-offset, 2));
        float b = (M_PI_F/2-atan(velScale-offset+radius))*2/M_PI_F;
        r = 1;
        g = 1;
        b = 1;
        particle.color = float3(r, g, b);
        
        
        particles[id] = particle;
    }
}

