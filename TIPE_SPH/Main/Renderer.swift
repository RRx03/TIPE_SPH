import MetalKit
import simd
//test
class Renderer : NSObject{
    static var device : MTLDevice!
    static var commanQueue : MTLCommandQueue!
    static var library : MTLLibrary!
    
    var renderPipelineState : MTLRenderPipelineState!
    
    var params = Params()
    var uniforms = Uniforms()
    
    
    var lastTime: Double = CFAbsoluteTimeGetCurrent()
    
    
    var particleMesh : MTKMesh
    var particles : [Particle] = [Particle(position: [0, 0, 0], velocity: [0, 0, 0], currentForce: [0, 0, 0], density: 0, pressure: 0)]
    var particleBuffer : MTLBuffer!
    var camera : Camera!



    
    init(metalView: MTKView){
        let device = MTLCreateSystemDefaultDevice()
        let commandQueue = device?.makeCommandQueue()
        Renderer.device = device
        Renderer.commanQueue = commandQueue
        camera = Camera(position: [0, 0, -3])
        
        particleBuffer = Renderer.device.makeBuffer(bytes: &particles, length: MemoryLayout<Particle>.stride*particles.count)
        
        let allocator = MTKMeshBufferAllocator(device: Renderer.device)
        let sphereMesh = MDLMesh(sphereWithExtent: [ParticleSettings.Radius, ParticleSettings.Radius, ParticleSettings.Radius],
                                 segments: [ParticleSettings.meshPrecision, ParticleSettings.meshPrecision],
                                 inwardNormals: false,
                                 geometryType: .triangles,
                                 allocator: allocator)
        
        do {
            particleMesh = try MTKMesh(mesh: sphereMesh, device: Renderer.device)
        } catch {
            fatalError("Error Mesh")
        }
        

        
        super.init()
        
        let library = Renderer.device.makeDefaultLibrary()
        Renderer.library = library
        let vertex = library?.makeFunction(name: "draw")
        let fragment = library?.makeFunction(name: "Fragment")
        let renderPipelineStateDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        renderPipelineStateDescriptor.vertexFunction = vertex
        renderPipelineStateDescriptor.fragmentFunction = fragment
        renderPipelineStateDescriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(particleMesh.vertexDescriptor)
        
        do{
            renderPipelineState = try Renderer.device.makeRenderPipelineState(descriptor: renderPipelineStateDescriptor)
        }catch {
            fatalError("Fail")
        }
        
        params.width = Int32(Settings.width)
        params.height = Int32(Settings.height)
        
        var projectionMatrix: float4x4 {float4x4(projectionFov: Settings.fov, near: Settings.nearPlan, far: Settings.farPlan, aspect: Float(params.width)/Float(params.height))}
        uniforms.projectionMatrix = projectionMatrix
        
        metalView.device = Renderer.device
        metalView.framebufferOnly = false
        metalView.delegate = self
        mtkView(metalView, drawableSizeWillChange: metalView.bounds.size)
        metalView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        
        
    }
    

}

extension Renderer: MTKViewDelegate {
    func mtkView(_: MTKView, drawableSizeWillChange _: CGSize) {}
    func draw(in view: MTKView) {
        guard let commandBuffer = Renderer.commanQueue.makeCommandBuffer() else {return}
        guard let renderPassDescriptor = view.currentRenderPassDescriptor else {return}
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {return}
        
        let currentTime = CFAbsoluteTimeGetCurrent()
        let deltaTime = Float(currentTime - lastTime)
        lastTime = currentTime
        
        uniforms.viewMatrix = camera.viewMatrix
        uniforms.deltaTime = deltaTime;
        
        renderEncoder.setRenderPipelineState(renderPipelineState)
        
        let submesh = particleMesh.submeshes[0]

        renderEncoder.setVertexBuffer(particleMesh.vertexBuffers[0].buffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(particleBuffer, offset: 0, index: 1)
        renderEncoder.setFragmentBytes(&params, length: MemoryLayout<Uniforms>.stride, index: 12)
        renderEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 11)
        renderEncoder.drawIndexedPrimitives(type: .triangle, indexCount: submesh.indexCount, indexType: submesh.indexType, indexBuffer:submesh.indexBuffer.buffer, indexBufferOffset: 0, instanceCount: Int(ParticleSettings.particleCount))

        
        
        
        renderEncoder.endEncoding()
        guard let drawable = view.currentDrawable else {return}
        commandBuffer.present(drawable)
        commandBuffer.commit()
                
        
    }
}
