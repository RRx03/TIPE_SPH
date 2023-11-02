#include <metal_stdlib>

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

uint hashkey(int3 coords, uint total){
    
    int temp1 = (coords.x*92837111)^(coords.y*689287499)^(coords.z*283923481);
    return uint(abs(temp1) % total);

}
int3 CellCoords (float3 pos, float gridSize){
    return int3(pos/(gridSize*2));

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

kernel void CellUpdate (device Particle *particles [[buffer(1)]],
                        device Combo *combo [[buffer(2)]],
                        constant Uniforms &uniforms [[buffer(11)]],
                        uint id [[thread_position_in_grid]])
{
    Particle particle = particles[id];
    int3 cellCoords = CellCoords(particle.position, uniforms.hConst);
    combo[id].ID = id;
    combo[id].hashKey = hashkey(cellCoords ,uniforms.particleCount);
    
}


kernel void PairSort(device Combo *combo [[buffer(2)]],
                     constant BitonicSorterParams &params [[buffer(13)]],
                     uint id [[thread_position_in_grid]])
{
    uint i = id;
    uint h = i & (params.groupWidth - 1);
    uint indexLow = h + (params.groupHeight+1)*(i/(params.groupWidth));
    uint indexHigh = indexLow + (params.stepIndex == 0 ? params.groupHeight - 2*h : (params.groupHeight +1)/2);

    if (indexHigh >= uint(params.bufferLength)){
        return;
    }

    Combo valueLow = combo[indexLow];
    Combo valueHigh = combo[indexHigh];

    if (valueLow.hashKey > valueHigh.hashKey){
        combo[indexLow] = valueHigh;
        combo[indexHigh] = valueLow;
    }

}

kernel void StartIndices (device Combo *combo [[buffer(2)]],
                          device uint *startIndices[[buffer(3)]],
                        constant Uniforms &uniforms [[buffer(11)]],
                        uint id [[thread_position_in_grid]])
{
    if(id == 0){
        startIndices[combo[id].hashKey] = id;
    }
    if(combo[id].hashKey != combo[id-1].hashKey){
        startIndices[combo[id].hashKey] = id;
    }
    else {
        return;
    }
}



kernel void updateParticles(device Particle *particles [[buffer(1)]],
                            device Combo *combo [[buffer(2)]],
                            device uint *startIndices [[buffer(3)]],
                            constant Uniforms &uniforms [[buffer(11)]],
                            uint id [[thread_position_in_grid]])
{
    
    
    Particle particle = particles[id];
    
    int3 cellCoords = CellCoords(particle.position, uniforms.hConst);
    
    particle.forces = float3(0, -uniforms.gravity * uniforms.particleMass, 0);
    float updateDeltaTime = uniforms.deltaTime;
    
//    
//    uint NeighBCells[27]; //Stores HashKeys
//    
//    for (int i = 0; i < 27; i++){
//        int3 NeighBCellCoords = cellCoords + NeighB[i];
//        NeighBCells[i] = hashkey(NeighBCellCoords, uniforms.particleCount);
//        int index = startIndices[NeighBCells[i]];
//        if (index < uniforms.particleCount){
//            
//        
//        
//        while (combo[index].hashKey == NeighBCells[i]){
//            if (combo[index].ID != id){
//                Particle otherParticle = particles[combo[index].ID];
//                float3 diff = otherParticle.position - particle.position; //Continous collisions (text for position + Vel (= Verlet vel) etc etc ad test for distance ...)
//                float dist = length(diff);
//                if(dist != 0){
//                    float3 Ndiff = normalize(diff);
//                    if(dist < uniforms.particleRadius*2){
//                        particle.position += -Ndiff*(uniforms.particleRadius*2-dist)/2; //this would allow bouncing coefficient to get introduced
//                        otherParticle.position += Ndiff*(uniforms.particleRadius*2-dist)/2;
//                        particles[combo[index].ID] = otherParticle;
//                    }
//                }
//                if(dist < uniforms.hConst){
//                    particle.rho += uniforms.particleMass*Weight(dist/uniforms.hConst, uniforms.hConst3);
//                }
//            }
//            
//            
//            index++;
//        }
//    }
//        
//        
//    }
    

    

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

