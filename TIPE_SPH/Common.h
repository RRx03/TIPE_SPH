
#ifndef Common_h
#define Common_h

#import <simd/simd.h>


typedef struct {
    matrix_float4x4 modelMatrix;
    matrix_float4x4 viewMatrix;
    matrix_float4x4 projectionMatrix;
    matrix_float3x3 normalMatrix;
    float deltaTime;
} Uniforms;


typedef struct {
    int width;
    int height;
} Params;


typedef struct { 
    simd_float3 position;
    simd_float3 velocity;
    simd_float3 currentForce;
    float density;
    float pressure;
    
}Particle;




#endif
