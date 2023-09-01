import MetalKit

class GameController : NSObject {
    
    var renderer : Renderer
    
    var particles : [Particle] = []
    static var particleBuffer : MTLBuffer!
    
    var lastTime: Double = CFAbsoluteTimeGetCurrent()

    
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
        particles = Array(repeating: Particle(), count: Int(ParticleSettings.particleCount))
        GameController.particleBuffer = Renderer.device.makeBuffer(bytes: &particles, length: MemoryLayout<Particle>.stride*Int(ParticleSettings.particleCount))
        var pointer = GameController.particleBuffer.contents().bindMemory(to: Particle.self, capacity: Int(ParticleSettings.particleCount))
        for _ in particles {
            pointer.pointee.position = [Float.random(in: -3...3), Float.random(in: 0...3), Float.random(in: -3...3)+10]
            pointer = pointer.advanced(by: 1)
        }
    
    }
    func update(deltaTime : Float){
        var pointer = GameController.particleBuffer.contents().bindMemory(to: Particle.self, capacity: Int(ParticleSettings.particleCount))
        for _ in particles {
            
            pointer.pointee.currentForce = [0, -9.81, 0]
            pointer.pointee.velocity += pointer.pointee.currentForce * deltaTime
            pointer.pointee.position += pointer.pointee.velocity * deltaTime
            
            if (pointer.pointee.position.y < 0){
                pointer.pointee.position.y += abs(pointer.pointee.position.y) //ajouter collision continues la c'est fu**ed up
                pointer.pointee.velocity.y *= -1
            }
            
            
            pointer = pointer.advanced(by: 1)
        }
        
    }
    
    
    
}

extension GameController : MTKViewDelegate{
    func mtkView(_ view: MTKView, drawableSizeWillChange _: CGSize) {}
    
    func draw(in view: MTKView) {
        
        let currentTime = CFAbsoluteTimeGetCurrent()
        let deltaTime = Float(currentTime - lastTime)
        lastTime = currentTime
        
        self.update(deltaTime: deltaTime)
        renderer.render(view: view, deltaTime: deltaTime)
        
        
        
    }
}
