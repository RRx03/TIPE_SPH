import MetalKit


class Renderer : NSObject {
    static var device : MTLDevice!
    static var commandQueue : MTLCommandQueue!
    static var library : MTLLibrary!
    
    var renderPipelineState : MTLRenderPipelineState!
    let depthStencilState: MTLDepthStencilState?

    
    var uniforms : Uniforms = Uniforms()
    var params : Params = Params()
    
    
    var mesh : MTKMesh
    
    static func buildDepthStencilState() -> MTLDepthStencilState? {
        let descriptor = MTLDepthStencilDescriptor()
        descriptor.depthCompareFunction = .less
        descriptor.isDepthWriteEnabled = true
        return Renderer.device.makeDepthStencilState(
            descriptor: descriptor)
    }
    
    init(metalView : MTKView){
        let device = MTLCreateSystemDefaultDevice()
        let commandQueue = device?.makeCommandQueue()
        Renderer.device = device
        Renderer.commandQueue = commandQueue
        depthStencilState = Self.buildDepthStencilState()

        
        
        
        var mtkMesh: MTKMesh
        let allocator = MTKMeshBufferAllocator(device: Renderer.device)
        let sphereMesh = MDLMesh(sphereWithExtent: [ParticleSettings.radius, ParticleSettings.radius, ParticleSettings.radius],
                                 segments: [ParticleSettings.meshPrecision, ParticleSettings.meshPrecision],
                                 inwardNormals: false,
                                 geometryType: .triangles,
                                 allocator: allocator)
        
        do {
            mtkMesh = try MTKMesh(mesh: sphereMesh, device: Renderer.device)
        } catch {
            fatalError("Error Mesh")
        }
        mesh = mtkMesh
        
        super.init()
        
        let library = device?.makeDefaultLibrary()
        Renderer.library = library
        let vertex = library?.makeFunction(name: "Vertex")
        let fragment = library?.makeFunction(name: "Fragment")
        let renderPipelineStateDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineStateDescriptor.vertexFunction = vertex
        renderPipelineStateDescriptor.fragmentFunction = fragment
        renderPipelineStateDescriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(mesh.vertexDescriptor)
        renderPipelineStateDescriptor.colorAttachments[0].pixelFormat = metalView.colorPixelFormat
        renderPipelineStateDescriptor.depthAttachmentPixelFormat = .depth32Float

        
        do {
            renderPipelineState = try Renderer.device.makeRenderPipelineState(descriptor: renderPipelineStateDescriptor)
        }catch{
            fatalError("Fail")
        }
        
        
        
        params.width = Float(Settings.width)
        params.height = Float(Settings.height)
        
        var projectionMatrix: float4x4 {float4x4(projectionFov: Settings.fov, near: Settings.nearPlan, far: Settings.farPlan, aspect: Float(params.width)/Float(params.height))}
        uniforms.projectionMatrix = projectionMatrix
        

    }
    func render(view : MTKView){
        guard let commandBuffer = Renderer.commandQueue.makeCommandBuffer() else {return}
        guard let renderPass = view.currentRenderPassDescriptor else {return}
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor:renderPass) else {return}
        
        renderEncoder.setDepthStencilState(depthStencilState)
        renderEncoder.setRenderPipelineState(renderPipelineState)
        
        uniforms.viewMatrix = float4x4(translation: [0, 0, -10]).inverse // Camera translation (no Rotation)

        
        let submesh = mesh.submeshes[0]
        

        renderEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 11)
        renderEncoder.setFragmentBytes(&params, length: MemoryLayout<Params>.stride, index: 12)
        renderEncoder.setVertexBuffer(mesh.vertexBuffers[0].buffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(GameController.particleBuffer, offset: 0, index: 1)

        renderEncoder.drawIndexedPrimitives(
                type: .triangle,
                indexCount: submesh.indexCount,
                indexType: submesh.indexType,
                indexBuffer: submesh.indexBuffer.buffer,
                indexBufferOffset: submesh.indexBuffer.offset,
                instanceCount: Int(ParticleSettings.particleCount))
        
        
        
        
        
        renderEncoder.endEncoding()
        guard let drawable = view.currentDrawable else {return}
        commandBuffer.present(drawable)
        commandBuffer.commit()
        
    }
    
}

