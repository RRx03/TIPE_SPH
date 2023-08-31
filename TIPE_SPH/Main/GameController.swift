import MetalKit
import MetalPerformanceShaders
import simd


class GameController : NSObject {
    
    static var renderer : Renderer!
    static var metalView : MTKView!
    
    static var particleMesh : ParticleMesh!
    var particles : [Particle] = []
    static var particleBuffer : MTLBuffer!
    
    static var camera : Camera!
    
    init(metalView : MTKView){
        GameController.metalView = metalView
        GameController.particleMesh = ParticleMesh()
        GameController.camera = Camera(position: [0, 0, -3])
        GameController.renderer = Renderer(metalView: metalView)

        super.init()
        
        metalView.device = Renderer.device
        metalView.framebufferOnly = false
        metalView.delegate = self
        mtkView(metalView, drawableSizeWillChange: metalView.bounds.size)
        metalView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        
        initParticles()
        
        
    }
    func initParticles (){
        particles = Array(repeating: Particle(position: [0, 0, 0], velocity: [0, 0, 0], currentForce: [0, 0, 0], density: 0, pressure: 0), count: Int(ParticleSettings.particleCount))
        GameController.particleBuffer = Renderer.device.makeBuffer(bytes: &particles, length: Int(ParticleSettings.particleCount)*MemoryLayout<Particle>.stride)
        
    }
    
}

extension GameController: MTKViewDelegate {
    func mtkView(_: MTKView, drawableSizeWillChange _: CGSize) {}
    func draw(in view: MTKView) {
        GameController.renderer.render(metalView: view)
        
    }
}



struct ParticleMesh {
    static var mesh : MTKMesh {
        var mtkMesh: MTKMesh
        let allocator = MTKMeshBufferAllocator(device: Renderer.device)
        let sphereMesh = MDLMesh(sphereWithExtent: [ParticleSettings.Radius, ParticleSettings.Radius, ParticleSettings.Radius],
                                 segments: [ParticleSettings.meshPrecision, ParticleSettings.meshPrecision],
                                 inwardNormals: false,
                                 geometryType: .triangles,
                                 allocator: allocator)
        
        do {
            mtkMesh = try MTKMesh(mesh: sphereMesh, device: Renderer.device)
        } catch {
            fatalError("Error Mesh")
        }
        return mtkMesh
    }

}
