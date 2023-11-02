import MetalKit

class Renderer: NSObject {
    static var device: MTLDevice!
    static var commandQueue: MTLCommandQueue!
    static var library: MTLLibrary!
    
    var renderPipelineState: MTLRenderPipelineState!
    var computePipelineState: MTLComputePipelineState!
    var cellPipelineState: MTLComputePipelineState!
    var pairSorterPipelineState: MTLComputePipelineState!
    var setupIndicesPipelineState: MTLComputePipelineState!

    let depthStencilState: MTLDepthStencilState?

    var uniforms: Uniforms = .init()
    var params: Params = .init()
    
    var mesh: MTKMesh
    
    static var comboBuffer: MTLBuffer!
    var startIndicesBuffer: MTLBuffer!

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
        
        Renderer.comboBuffer = Renderer.device.makeBuffer(bytes: &GameController.comboArr, length: MemoryLayout<Combo>.stride * Int(ParticleSettings.particleCount))
        startIndicesBuffer = Renderer.device.makeBuffer(bytes: &GameController.startIndices, length: MemoryLayout<UInt32>.stride * Int(ParticleSettings.particleCount))
        
        super.init()
        
        // MARK: - Creating PSOs (maybe create a new file for this)

        let library = device?.makeDefaultLibrary()
        Renderer.library = library
        let vertex = library?.makeFunction(name: "Vertex")
        let fragment = library?.makeFunction(name: "Fragment")
        let kernel = library?.makeFunction(name: "updateParticles")
        let cell = library?.makeFunction(name: "CellUpdate")
        let PairSort = library?.makeFunction(name: "PairSort")
        let setupIndices = library?.makeFunction(name: "StartIndices")

        let renderPipelineStateDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineStateDescriptor.vertexFunction = vertex
        renderPipelineStateDescriptor.fragmentFunction = fragment
        renderPipelineStateDescriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(mesh.vertexDescriptor)
        renderPipelineStateDescriptor.colorAttachments[0].pixelFormat = metalView.colorPixelFormat
        renderPipelineStateDescriptor.depthAttachmentPixelFormat = .depth32Float

        do {
            renderPipelineState = try Renderer.device.makeRenderPipelineState(descriptor: renderPipelineStateDescriptor)
            computePipelineState = try Renderer.device.makeComputePipelineState(function: kernel!)
            cellPipelineState = try Renderer.device.makeComputePipelineState(function: cell!)
            pairSorterPipelineState = try Renderer.device.makeComputePipelineState(function: PairSort!)
            setupIndicesPipelineState = try Renderer.device.makeComputePipelineState(function: setupIndices!)

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
        uniforms.globalFriction = Settings.globalFriction
        uniforms.hConst = ParticleSettings.h
        uniforms.hConst3 = pow(ParticleSettings.h, 3)
        uniforms.hConst9 = pow(ParticleSettings.h, 9)
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

        // MARK: - Cell Dispatching

        guard let commandComputeBuffer = Renderer.commandQueue.makeCommandBuffer() else { return }
        guard let computeEncoder: MTLComputeCommandEncoder = commandComputeBuffer.makeComputeCommandEncoder(dispatchType: MTLDispatchType.serial) else { return }
        
        computeEncoder.setComputePipelineState(cellPipelineState)

        var w: Int = computePipelineState.maxTotalThreadsPerThreadgroup
        var threadsPerGrid = MTLSize(width: Int(ParticleSettings.particleCount), height: 1, depth: 1)
        var threadsPerThreadgroup = MTLSize(width: w, height: 1, depth: 1)
        
        computeEncoder.setBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 11)
        computeEncoder.setBuffer(GameController.particleBuffer, offset: 0, index: 1)
        computeEncoder.setBuffer(Renderer.comboBuffer, offset: 0, index: 2)
        computeEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        
        computeEncoder.endEncoding()
        commandComputeBuffer.commit()
        commandComputeBuffer.waitUntilCompleted()
        
        // MARK: - Bitonic Sort + Start Indices

//        BitonicSortSerial()
//
//        guard let commandComputeBuffer = Renderer.commandQueue.makeCommandBuffer() else { return }
//        guard let computeEncoder: MTLComputeCommandEncoder = commandComputeBuffer.makeComputeCommandEncoder(dispatchType: MTLDispatchType.serial) else { return }
//        
//        computeEncoder.setComputePipelineState(setupIndicesPipelineState)
//        
//        w = computePipelineState.maxTotalThreadsPerThreadgroup
//        threadsPerGrid = MTLSize(width: Int(ParticleSettings.particleCount), height: 1, depth: 1)
//        threadsPerThreadgroup = MTLSize(width: w, height: 1, depth: 1)
//        
//        computeEncoder.setBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 11)
//        computeEncoder.setBuffer(Renderer.comboBuffer, offset: 0, index: 2)
//        computeEncoder.setBuffer(startIndicesBuffer, offset: 0, index: 3)
//        computeEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
//        
//        computeEncoder.endEncoding()
//        commandComputeBuffer.commit()
//        commandComputeBuffer.waitUntilCompleted()
//        
//        if (Settings.debugMode){
//            
//            var comboBufferPtr = Renderer.comboBuffer.contents().assumingMemoryBound(to: Combo.self)
//            var startIndicesPtr = startIndicesBuffer.contents().assumingMemoryBound(to: UInt32.self)
//            
//            for _ in 0..<Int(ParticleSettings.particleCount) {
//                print("ID - \(comboBufferPtr.pointee.ID) -HashKey-> \(comboBufferPtr.pointee.hashKey) / \(startIndicesPtr.pointee)")
//                comboBufferPtr+=1
//                startIndicesPtr+=1
//            }
//            print("Sorted")
//        }

        // MARK: - PARTICLES
        
        guard let commandComputeBuffer = Renderer.commandQueue.makeCommandBuffer() else { return }
        guard let computeEncoder: MTLComputeCommandEncoder = commandComputeBuffer.makeComputeCommandEncoder(dispatchType: MTLDispatchType.serial) else { return }
        
        computeEncoder.setComputePipelineState(computePipelineState)
        
        w = computePipelineState.maxTotalThreadsPerThreadgroup
        threadsPerGrid = MTLSize(width: Int(ParticleSettings.particleCount), height: 1, depth: 1)
        threadsPerThreadgroup = MTLSize(width: w, height: 1, depth: 1)

        computeEncoder.setBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 11)
        computeEncoder.setBuffer(GameController.particleBuffer, offset: 0, index: 1)
        computeEncoder.setBuffer(Renderer.comboBuffer, offset: 0, index: 2)
        computeEncoder.setBuffer(startIndicesBuffer, offset: 0, index: 3)
        computeEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        
        computeEncoder.endEncoding()
        commandComputeBuffer.commit()
        commandComputeBuffer.waitUntilCompleted() // USELESS?
    }
    
    func NextPoxerOfTwo(value: Int32) -> Int32 {
        return 1 << Int32(ceil(log2(Double(value))))
    }
    
    func BitonicSortSerial() // Peut etre rendre le buffer static et directement aller le chercher avec Renderer.jkegfjhzehf
    {
        var bitonicParams = BitonicSorterParams()
        let bufferLength = Int32(Renderer.comboBuffer.length/MemoryLayout<Combo>.stride)
        let numPairs = NextPoxerOfTwo(value: bufferLength)/2
        let numStages = Int32(log2(Double(numPairs * 2)))
        bitonicParams.bufferLength = bufferLength
        
        for stageIndex in 0..<numStages {
            for stepIndex in 0..<(stageIndex + 1) {
                let groupWidth: Int32 = 1 << (stageIndex - stepIndex)
                let groupHeight: Int32 = 2 * groupWidth - 1
                
                bitonicParams.groupWidth = groupWidth
                bitonicParams.groupHeight = groupHeight
                bitonicParams.stepIndex = stepIndex
                
                guard let commandBuffer = Renderer.commandQueue.makeCommandBuffer() else { return }
                guard let commandEncoder: MTLComputeCommandEncoder = commandBuffer.makeComputeCommandEncoder(dispatchType: MTLDispatchType.serial) else { return }
                
                commandEncoder.setComputePipelineState(pairSorterPipelineState)
                commandEncoder.setBuffer(Renderer.comboBuffer, offset: 0, index: 2)
                commandEncoder.setBytes(&bitonicParams, length: MemoryLayout<BitonicSorterParams>.stride, index: 13)
                let gridSize = MTLSize(width: Int(numPairs), height: 1, depth: 1)
                let threadGroupSize = MTLSize(width: 128, height: 1, depth: 1)
                commandEncoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadGroupSize)
                commandEncoder.endEncoding()
                commandBuffer.commit()
                commandBuffer.waitUntilCompleted()
            }
        }
    }
}
