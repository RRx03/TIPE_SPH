
#ifndef Common_h
#define Common_h

#import <simd/simd.h>

typedef struct {
    matrix_float4x4 viewMatrix;
    matrix_float4x4 projectionMatrix;
    
    float deltaTime;
    
    simd_float3 containerSize;
    simd_float3 containerPosition;
    
    int particleCount;
    float particleMass;
    float particleBouncingCoefficient;
    float particleViscosity;
    float particleGazConstant;
    float particleRestDensity;
    float particleVolume;
    float hConst;
    float hConst2;
    float hConst9;
    
    
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
    float viscosity;

    

} Particle;

typedef struct {

    

} SimulationSettings;

#endif
