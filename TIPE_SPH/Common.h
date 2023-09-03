
#ifndef Common_h
#define Common_h

#import <simd/simd.h>

typedef struct {
    matrix_float4x4 viewMatrix;
    matrix_float4x4 projectionMatrix;
    
    float deltaTime;
    float particleMass;
    float particleBouncingCoefficient;
    
    
} Uniforms;


typedef struct {
    float width;
    float height;
} Params;


typedef struct {
    simd_float3 position;
    simd_float3 velocity;
    simd_float3 acceleration;
    float pressure;
    float density;
    

} Particle;

typedef struct {

    

} SimulationSettings;

#endif
