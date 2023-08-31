import MetalKit

//test
class Renderer{
    static var device : MTLDevice!
    static var commanQueue : MTLCommandQueue!
    static var library : MTLLibrary!
    
    var renderPipelineState : MTLRenderPipelineState!
    
    var params = Params()
    var uniforms = Uniforms()
    
    
    var lastTime: Double = CFAbsoluteTimeGetCurrent()

    
    init(metalView: MTKView){
        let device = MTLCreateSystemDefaultDevice()
        let commandQueue = device?.makeCommandQueue()
        Renderer.device = device
        Renderer.commanQueue = commandQueue
        
        let library = Renderer.device.makeDefaultLibrary()
        Renderer.library = library
        let vertex = library?.makeFunction(name: "draw")
        let fragment = library?.makeFunction(name: "Fragment")
        let renderPipelineStateDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        renderPipelineStateDescriptor.vertexFunction = vertex
        renderPipelineStateDescriptor.fragmentFunction = fragment
        renderPipelineStateDescriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(ParticleMesh.mesh.vertexDescriptor)
        
        do{
            renderPipelineState = try Renderer.device.makeRenderPipelineState(descriptor: renderPipelineStateDescriptor)
        }catch {
            fatalError("Fail")
        }
        
        params.width = Int32(Settings.width)
        params.height = Int32(Settings.height)
        
        var projectionMatrix: float4x4 {float4x4(projectionFov: Settings.fov, near: Settings.nearPlan, far: Settings.farPlan, aspect: Float(params.width)/Float(params.height))}
        uniforms.projectionMatrix = projectionMatrix
        
    }
    
    func render(metalView : MTKView){
        
        
        
        guard let commandBuffer = Renderer.commanQueue.makeCommandBuffer() else {return}
        guard let renderPassDescriptor = metalView.currentRenderPassDescriptor else {return}
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {return}
        
        let currentTime = CFAbsoluteTimeGetCurrent()
        let deltaTime = Float(currentTime - lastTime)
        lastTime = currentTime
        
        uniforms.viewMatrix = GameController.camera.viewMatrix
        uniforms.deltaTime = deltaTime;
        
        renderEncoder.setRenderPipelineState(renderPipelineState)
        
        let submesh = ParticleMesh.mesh.submeshes[0]

        renderEncoder.setVertexBuffer(ParticleMesh.mesh.vertexBuffers[0].buffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(GameController.particleBuffer, offset: 0, index: 1)
        renderEncoder.setFragmentBytes(&params, length: MemoryLayout<Uniforms>.stride, index: 12)
        renderEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 11)
        renderEncoder.drawIndexedPrimitives(type: .triangle, indexCount: submesh.indexCount, indexType: submesh.indexType, indexBuffer:submesh.indexBuffer.buffer, indexBufferOffset: 0, instanceCount: Int(ParticleSettings.particleCount))

        
        
        
        renderEncoder.endEncoding()
        guard let drawable = metalView.currentDrawable else {return}
        commandBuffer.present(drawable)
        commandBuffer.commit()
                
        
    }
}
