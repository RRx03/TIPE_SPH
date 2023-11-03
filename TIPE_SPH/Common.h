
#ifndef Common_h
#define Common_h

#import <simd/simd.h>

typedef struct {
    
    matrix_float4x4 viewMatrix;
    matrix_float4x4 projectionMatrix;
    
    float deltaTime;
    int subSteps;
    float gravity;


    simd_float3 containerSize;
    simd_float3 containerPosition;
    simd_int3 cellStruct;

    
    int particleCount;
    float cellSIZE;


    float particleMass;
    float particleBouncingCoefficient;
    float particleViscosity;
    float particleGazConstant;
    float particleRestDensity;
    float particleVolume;
    float particleRadius;
    float hConst;
    float hConst3;
    float hConst9;
    float globalFriction;
    
    
    

} Uniforms;


typedef struct {
    
    float width;
    float height;
    
} Params;

typedef struct {
    int bufferLength;
    int groupWidth;
    int groupHeight;
    int stepIndex;
    
} BitonicSorterParams;


typedef struct {
    
    simd_float3 position;
    simd_float3 oldPosition;
    simd_float3 velocity;
    simd_float3 acceleration;
    simd_float3 forces;
    simd_float3 color;
    float rho;
    float pressure;
    float density;
    float viscosity;

} Particle;

typedef struct {
    
    uint startIndex;
    uint Count;
    
} StartIndexCount;

#endif
