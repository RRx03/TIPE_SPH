import MetalKit


class Renderer : NSObject {
    
    
    static var device : MTLDevice!
    static var commandQueue : MTLCommandQueue!
    static var library : MTLLibrary!
    
    var renderPipelineState : MTLRenderPipelineState!
    var computePipelineState : MTLComputePipelineState!

    let depthStencilState: MTLDepthStencilState?

    
    var uniforms : Uniforms = Uniforms()
    var params : Params = Params()
    
    var mesh : MTKMesh
    
   
    
    init(metalView : MTKView){
        //MARK: - Basic Definitions
        let device = MTLCreateSystemDefaultDevice()
        let commandQueue = device?.makeCommandQueue()
        Renderer.device = device
        Renderer.commandQueue = commandQueue
        depthStencilState = Self.buildDepthStencilState()

        
        
        //MARK: - Loading the Particle Mesh (maybe create a struct for it)
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
        
        
        //MARK: - Creating PSOs (maybe create a new file for this)
        let library = device?.makeDefaultLibrary()
        Renderer.library = library
        let vertex = library?.makeFunction(name: "Vertex")
        let fragment = library?.makeFunction(name: "Fragment")
        let kernel = library?.makeFunction(name: "updateParticles")
        let renderPipelineStateDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineStateDescriptor.vertexFunction = vertex
        renderPipelineStateDescriptor.fragmentFunction = fragment
        renderPipelineStateDescriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(mesh.vertexDescriptor)
        renderPipelineStateDescriptor.colorAttachments[0].pixelFormat = metalView.colorPixelFormat
        renderPipelineStateDescriptor.depthAttachmentPixelFormat = .depth32Float

        
        do {
            renderPipelineState = try Renderer.device.makeRenderPipelineState(descriptor: renderPipelineStateDescriptor)
            computePipelineState = try Renderer.device.makeComputePipelineState(function: kernel!)
        }catch{
            fatalError("Fail")
        }
        
        
        
        //MARK: - Defining Settings
        params.width = Float(Settings.width)
        params.height = Float(Settings.height)
        var projectionMatrix: float4x4 {float4x4(projectionFov: Settings.fov, near: Settings.nearPlan, far: Settings.farPlan, aspect: Float(params.width)/Float(params.height))}
        uniforms.projectionMatrix = projectionMatrix
        uniforms.viewMatrix = float4x4(rotationX: -Float.pi/10) * float4x4(translation: [0, 10, -20]).inverse //Camera Position
        
        uniforms.gravity = Settings.gravity
        uniforms.particleMass = ParticleSettings.mass;
        uniforms.particleBouncingCoefficient = ParticleSettings.bouncingCoefficient;
        uniforms.containerSize = simd_float3(ParticleSettings.containerSize)
        uniforms.containerPosition = simd_float3(ParticleSettings.containerPosition)
        uniforms.particleCount = ParticleSettings.particleCount
        
        uniforms.particleVolume = ParticleSettings.Volume
        uniforms.particleRestDensity = ParticleSettings.restDensity
        uniforms.particleGazConstant = ParticleSettings.gazConstant
        uniforms.particleRadius = ParticleSettings.radius
        uniforms.groundFrictionCoefficient = ParticleSettings.groundFrictionCoefficient
        uniforms.hConst = ParticleSettings.h
        uniforms.hConst2 = pow(ParticleSettings.h, 2)
        uniforms.hConst9 = pow(ParticleSettings.h, 9)

        

    }
    
    static func buildDepthStencilState() -> MTLDepthStencilState? {
        let descriptor = MTLDepthStencilDescriptor()
        descriptor.depthCompareFunction = .less
        descriptor.isDepthWriteEnabled = true
        return Renderer.device.makeDepthStencilState(
            descriptor: descriptor)
    }
    
    func render(view : MTKView, deltaTime : Float){
        guard let commandRenderBuffer = Renderer.commandQueue.makeCommandBuffer() else {return}
        guard let renderPass = view.currentRenderPassDescriptor else {return}
        guard let renderEncoder = commandRenderBuffer.makeRenderCommandEncoder(descriptor:renderPass) else {return}
        guard let commandComputeBuffer = Renderer.commandQueue.makeCommandBuffer() else {return}
        guard let computeEncoder: MTLComputeCommandEncoder = commandComputeBuffer.makeComputeCommandEncoder() else {return}

        uniforms.deltaTime = deltaTime
        
        //MARK: - Computing

        computeEncoder.setComputePipelineState(computePipelineState)
        
        let w: Int = computePipelineState.threadExecutionWidth
        let threadsPerGrid = MTLSize(width: Int(ParticleSettings.particleCount), height: 1, depth: 1)
        let threadsPerThreadgroup = MTLSize(width: w, height: 1, depth: 1)
        
        computeEncoder.setBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 11)
        computeEncoder.setBuffer(GameController.particleBuffer, offset: 0, index: 1)
        computeEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        
        computeEncoder.endEncoding()
        commandComputeBuffer.commit()
        commandComputeBuffer.waitUntilCompleted()
        
        //MARK: - Rendering
        
        
        renderEncoder.setDepthStencilState(depthStencilState)
        renderEncoder.setRenderPipelineState(renderPipelineState)
        
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
        commandRenderBuffer.present(drawable)
        commandRenderBuffer.commit()

        
    }
    
}

