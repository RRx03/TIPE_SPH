import MetalKit


class Renderer : NSObject {
    static var device : MTLDevice!
    static var commandQueue : MTLCommandQueue!
    static var library : MTLLibrary!
    var renderPipelineState : MTLRenderPipelineState!
    
    
    var mesh : MTKMesh
    
    
    init(metalView : MTKView){
        let device = MTLCreateSystemDefaultDevice()
        let commandQueue = device?.makeCommandQueue()
        Renderer.device = device
        Renderer.commandQueue = commandQueue
        
        
        
        var mtkMesh: MTKMesh
        let allocator = MTKMeshBufferAllocator(device: Renderer.device)
        let sphereMesh = MDLMesh(sphereWithExtent: [1, 1, 1],
                                 segments: [100, 100],
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
        renderPipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        do {
            renderPipelineState = try Renderer.device.makeRenderPipelineState(descriptor: renderPipelineStateDescriptor)
        }catch{
            fatalError("Fail")
        }
        
        metalView.device = Renderer.device
        metalView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        metalView.delegate = self
        

    }
    
}

extension Renderer : MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange _: CGSize) {}
    
    func draw(in view: MTKView) {
        
        guard let commandBuffer = Renderer.commandQueue.makeCommandBuffer() else {return}
        guard let renderPass = view.currentRenderPassDescriptor else {return}
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor:renderPass) else {return}
        
        renderEncoder.setRenderPipelineState(renderPipelineState)
        
        
        renderEncoder.setVertexBuffer(mesh.vertexBuffers[0].buffer, offset: 0, index: 0)
        
        for submesh in mesh.submeshes {
            renderEncoder.drawIndexedPrimitives(
                type: .triangle,
                indexCount: submesh.indexCount,
                indexType: submesh.indexType,
                indexBuffer: submesh.indexBuffer.buffer,
                indexBufferOffset: submesh.indexBuffer.offset)
        }
        
        
        
        
        renderEncoder.endEncoding()
        guard let drawable = view.currentDrawable else {return}
        commandBuffer.present(drawable)
        commandBuffer.commit()
        
        
        
    }
    
    
    
}
    


