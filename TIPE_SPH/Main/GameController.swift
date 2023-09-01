import MetalKit

class GameController : NSObject {
    
    var renderer : Renderer
    
    var particles : [Particle] = []
    static var particleBuffer : MTLBuffer!
    
    init(metalView : MTKView){
        
        
        renderer = Renderer(metalView: metalView)
        
        super.init()
        
        metalView.device = Renderer.device
        metalView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        metalView.depthStencilPixelFormat = .depth32Float
        metalView.delegate = self
        
        
        
        
        initParticles()
        
        

        
    }
    func initParticles(){
        particles = Array(repeating: Particle(position: [0, 0, 0]), count: Int(ParticleSettings.particleCount))
        GameController.particleBuffer = Renderer.device.makeBuffer(bytes: &particles, length: MemoryLayout<Particle>.stride*Int(ParticleSettings.particleCount))
        var pointer = GameController.particleBuffer.contents().bindMemory(to: Particle.self, capacity: Int(ParticleSettings.particleCount))
        for _ in particles {
            pointer.pointee.position = [Float.random(in: -1...1), Float.random(in: -1...1), Float.random(in: -1...1)]
            pointer = pointer.advanced(by: 1)
        }
    
    }
    
    
    
}

extension GameController : MTKViewDelegate{
    func mtkView(_ view: MTKView, drawableSizeWillChange _: CGSize) {}
    
    func draw(in view: MTKView) {
        
        renderer.render(view: view)
        
        
        
    }
}
