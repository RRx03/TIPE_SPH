import Foundation
import CoreGraphics


struct Camera{

    var position :  float3

    var projectionMatrix: float4x4 {
        float4x4(
            projectionFov: Settings.fov,
            near: Settings.nearPlan,
            far: Settings.farPlan,
            aspect: Float(Settings.width)/Float(Settings.height))
    }
    
    var viewMatrix: float4x4 {
        (float4x4(translation: position)).inverse
    }
    
}
