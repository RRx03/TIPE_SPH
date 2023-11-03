import MetalKit

class Renderer: NSObject {
    static var device: MTLDevice!
    static var commandQueue: MTLCommandQueue!
    static var library: MTLLibrary!
    
    var renderPipelineState: MTLRenderPipelineState!
    var computePipelineState: MTLComputePipelineState!
    var initTablePSO: MTLComputePipelineState!
    var assignDenseTablePSO: MTLComputePipelineState!

    let depthStencilState: MTLDepthStencilState?

    var uniforms: Uniforms = .init()
    var params: Params = .init()
    
    var mesh: MTKMesh
    
    var tableArray: [UInt32] = .init(repeating: 0, count: Int(ParticleSettings.particleCount) + 1)
    var denseTableArray: [UInt32] = .init(repeating: 0, count: Int(ParticleSettings.particleCount))
    var startIndexArray: [StartIndexCount] = .init(repeating: StartIndexCount(startIndex: UInt32(ParticleSettings.particleCount), Count: 0), count: Int(ParticleSettings.particleCount))
    
    var table: MTLBuffer!
    var denseTable: MTLBuffer!
    var startIndex: MTLBuffer!
    
    init(metalView: MTKView) {
        
        // MARK: - Basic Definitions
        let device = MTLCreateSystemDefaultDevice()
        let commandQueue = device?.makeCommandQueue()
        Renderer.device = device
        Renderer.commandQueue = commandQueue
        depthStencilState = Self.buildDepthStencilState()

        // MARK: - Loading the Particle Mesh (maybe create a struct for it)

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
        
        table = Renderer.device.makeBuffer(bytes: &tableArray, length: MemoryLayout<UInt32>.stride * (Int(ParticleSettings.particleCount) + 1))
        denseTable = Renderer.device.makeBuffer(bytes: &denseTableArray, length: MemoryLayout<UInt32>.stride * Int(ParticleSettings.particleCount))
        startIndex = Renderer.device.makeBuffer(bytes: &startIndexArray, length: MemoryLayout<StartIndexCount>.stride * Int(ParticleSettings.particleCount))

        super.init()
        
        // MARK: - Creating PSOs (maybe create a new file for this)

        let library = device?.makeDefaultLibrary()
        Renderer.library = library
        let vertex = library?.makeFunction(name: "Vertex")
        let fragment = library?.makeFunction(name: "Fragment")
        let kernel = library?.makeFunction(name: "updateParticles")
        let initTableFunction = library?.makeFunction(name: "initTable")
        let assignDenseTableFunction = library?.makeFunction(name: "assignDenseTable")

        let renderPipelineStateDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineStateDescriptor.vertexFunction = vertex
        renderPipelineStateDescriptor.fragmentFunction = fragment
        renderPipelineStateDescriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(mesh.vertexDescriptor)
        renderPipelineStateDescriptor.colorAttachments[0].pixelFormat = metalView.colorPixelFormat
        renderPipelineStateDescriptor.depthAttachmentPixelFormat = .depth32Float

        do {
            renderPipelineState = try Renderer.device.makeRenderPipelineState(descriptor: renderPipelineStateDescriptor)
            computePipelineState = try Renderer.device.makeComputePipelineState(function: kernel!)
            initTablePSO = try Renderer.device.makeComputePipelineState(function: initTableFunction!)
            assignDenseTablePSO = try Renderer.device.makeComputePipelineState(function: assignDenseTableFunction!)

        } catch {
            fatalError("Fail")
        }
        
        // MARK: - Defining Settings

        params.width = Float(Settings.width)
        params.height = Float(Settings.height)
        var projectionMatrix: float4x4 { float4x4(projectionFov: Settings.fov, near: Settings.nearPlan, far: Settings.farPlan, aspect: Float(params.width)/Float(params.height)) }
        uniforms.projectionMatrix = projectionMatrix
        uniforms.viewMatrix = float4x4(rotationX: Settings.cameraAngle) * float4x4(translation: Settings.cameraPosition).inverse // Camera Position
        
        uniforms.gravity = Settings.gravity

        uniforms.particleMass = ParticleSettings.mass
        uniforms.particleBouncingCoefficient = ParticleSettings.bouncingCoefficient
        uniforms.containerSize = simd_float3(ParticleSettings.containerSize)
        uniforms.containerPosition = simd_float3(ParticleSettings.containerPosition)
        uniforms.particleCount = ParticleSettings.particleCount

        uniforms.particleVolume = ParticleSettings.Volume
        uniforms.particleRestDensity = ParticleSettings.restDensity
        uniforms.particleGazConstant = ParticleSettings.gazConstant
        uniforms.particleRadius = ParticleSettings.radius
        uniforms.hConst = ParticleSettings.h
        uniforms.hConst3 = pow(ParticleSettings.h, 3)
        uniforms.hConst9 = pow(ParticleSettings.h, 9)
        uniforms.cellSIZE = 2 * uniforms.hConst
        uniforms.subSteps = Settings.subSteps
    }
    
    static func buildDepthStencilState() -> MTLDepthStencilState? {
        let descriptor = MTLDepthStencilDescriptor()
        descriptor.depthCompareFunction = .less
        descriptor.isDepthWriteEnabled = true
        return Renderer.device.makeDepthStencilState(
            descriptor: descriptor)
    }
    
    func render(view: MTKView, deltaTime: Float) {
        /*
         Idees : commit git hub et cloner le projets pour le modif sur VSCODE
         Parraleliser les devices computings/rendering
         Revoir la syncro
         Triple buffering
         Retirer des vertices
         revoir le hash function pour qu'il compute plus vite (byte manip) et pour qu'il y ai moins voir casi aucune collision selon les config (car dans certaines c'est innevitatable).
         */
        
        uniforms.deltaTime = deltaTime
        print(1/deltaTime) // FPS
        
        // MARK: - Rendering

        guard let commandRenderBuffer = Renderer.commandQueue.makeCommandBuffer() else { return }
        guard let renderPass = view.currentRenderPassDescriptor else { return }
        guard let renderEncoder = commandRenderBuffer.makeRenderCommandEncoder(descriptor: renderPass) else { return }
        
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
        
        guard let drawable = view.currentDrawable else { return }
        commandRenderBuffer.present(drawable)
        commandRenderBuffer.commit()
        
        // MARK: - COMPUTING a faire avec un autre device en parallele

        // MARK: - initTable

        guard let commandComputeBuffer = Renderer.commandQueue.makeCommandBuffer() else { return }
        guard let computeEncoder: MTLComputeCommandEncoder = commandComputeBuffer.makeComputeCommandEncoder(dispatchType: MTLDispatchType.serial) else { return }
        
        computeEncoder.setComputePipelineState(initTablePSO)

        var maxThreads: Int = initTablePSO.maxTotalThreadsPerThreadgroup
        var gridSize = MTLSize(width: Int(ParticleSettings.particleCount), height: 1, depth: 1)
        var threadGroupSize = MTLSize(width: maxThreads, height: 1, depth: 1)
        
        computeEncoder.setBuffer(GameController.particleBuffer, offset: 0, index: 1)
        computeEncoder.setBuffer(table, offset: 0, index: 2)
        computeEncoder.setBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 11)
        computeEncoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadGroupSize)
        
        computeEncoder.endEncoding()
        commandComputeBuffer.commit()
        commandComputeBuffer.waitUntilCompleted()
        
        // MARK: - PartialSum
       
        var tablePtr = table.contents().assumingMemoryBound(to: UInt32.self)
        var sum : UInt32 = 0
        for _ in 0..<Int(ParticleSettings.particleCount) {
            sum = sum + tablePtr.pointee
            tablePtr.pointee = sum
            tablePtr+=1
        }
        tablePtr.pointee = sum

        // MARK: - assignDenseTable

        guard let commandComputeBuffer = Renderer.commandQueue.makeCommandBuffer() else { return }
        guard let computeEncoder: MTLComputeCommandEncoder = commandComputeBuffer.makeComputeCommandEncoder(dispatchType: MTLDispatchType.serial) else { return }
        
        computeEncoder.setComputePipelineState(assignDenseTablePSO)

        maxThreads = assignDenseTablePSO.maxTotalThreadsPerThreadgroup
        gridSize = MTLSize(width: Int(ParticleSettings.particleCount), height: 1, depth: 1)
        threadGroupSize = MTLSize(width: maxThreads, height: 1, depth: 1)
        
        computeEncoder.setBuffer(GameController.particleBuffer, offset: 0, index: 1)
        computeEncoder.setBuffer(table, offset: 0, index: 2)
        computeEncoder.setBuffer(denseTable, offset: 0, index: 3)
        computeEncoder.setBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 11)
        
        computeEncoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadGroupSize)
        computeEncoder.endEncoding()
        commandComputeBuffer.commit()
        commandComputeBuffer.waitUntilCompleted()
        
        // MARK: - StartIndex

        var startIndexPtr = startIndex.contents().assumingMemoryBound(to: StartIndexCount.self)
        tablePtr = table.contents().assumingMemoryBound(to: UInt32.self)
        startIndexPtr += Int(ParticleSettings.particleCount)-1
        tablePtr += Int(ParticleSettings.particleCount)
        var previousValue : UInt32 = tablePtr.pointee
        tablePtr -= 1
        for _ in 0..<Int(ParticleSettings.particleCount) {
            if (tablePtr.pointee != previousValue){
                startIndexPtr.pointee.startIndex = tablePtr.pointee
                startIndexPtr.pointee.Count = previousValue-tablePtr.pointee
            }
            previousValue = tablePtr.pointee
            startIndexPtr -= 1
            tablePtr -= 1
        }
        // MARK: - PARTICLES
        
        guard let commandComputeBuffer = Renderer.commandQueue.makeCommandBuffer() else { return }
        guard let computeEncoder: MTLComputeCommandEncoder = commandComputeBuffer.makeComputeCommandEncoder(dispatchType: MTLDispatchType.serial) else { return }
        
        computeEncoder.setComputePipelineState(computePipelineState)
        
        maxThreads = computePipelineState.maxTotalThreadsPerThreadgroup
        gridSize = MTLSize(width: Int(ParticleSettings.particleCount), height: 1, depth: 1)
        threadGroupSize = MTLSize(width: maxThreads, height: 1, depth: 1)
        

        computeEncoder.setBuffer(GameController.particleBuffer, offset: 0, index: 1)
        computeEncoder.setBuffer(table, offset: 0, index: 2)
        computeEncoder.setBuffer(denseTable, offset: 0, index: 3)
        computeEncoder.setBuffer(startIndex, offset: 0, index: 4)
        computeEncoder.setBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 11)
        
        computeEncoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadGroupSize)
        computeEncoder.endEncoding()
        commandComputeBuffer.commit()
        commandComputeBuffer.waitUntilCompleted()
        
        
        
        tablePtr = table.contents().assumingMemoryBound(to: UInt32.self)
        startIndexPtr = startIndex.contents().assumingMemoryBound(to: StartIndexCount.self)
        var denseTablePtr = denseTable.contents().assumingMemoryBound(to: UInt32.self)
        for _ in 0..<Int(ParticleSettings.particleCount) {
            tablePtr.pointee = 0
            denseTablePtr.pointee = 0
            startIndexPtr.pointee.startIndex = UInt32(ParticleSettings.particleCount)
            startIndexPtr.pointee.Count = 0
            
            tablePtr += 1
            denseTablePtr += 1
            startIndexPtr += 1
            
        }
        tablePtr.pointee = 0
    }
}
