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
        
        for y in 0..<ParticleSettings.gridPopulation[1] {
            for x in 0..<ParticleSettings.gridPopulation[0] {
                for z in 0..<ParticleSettings.gridPopulation[2] {
                    particles.append(Particle(position: [
                        Float(x)*ParticleSettings.gridSpacing[0]+ParticleSettings.gridPosition[0]+Float.random(in: -ParticleSettings.spawnJigger...ParticleSettings.spawnJigger),
                        Float(y)*ParticleSettings.gridSpacing[1]+ParticleSettings.gridPosition[1]+Float.random(in: -ParticleSettings.spawnJigger...ParticleSettings.spawnJigger),
                        Float(z)*ParticleSettings.gridSpacing[2]+ParticleSettings.gridPosition[2]+Float.random(in: -ParticleSettings.spawnJigger...ParticleSettings.spawnJigger)
                    ], velocity: [0, 0, 0], currentForce: [0, 0, 0], pressure: 0, density: 0))
                }
            }
        }
        GameController.particleBuffer = Renderer.device.makeBuffer(bytes: &particles, length: MemoryLayout<Particle>.stride*Int(ParticleSettings.particleCount))
        var pointer = GameController.particleBuffer.contents().bindMemory(to: Particle.self, capacity: Int(ParticleSettings.particleCount))
        for _ in particles {
            pointer.pointee.density = 0
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
                pointer.pointee.velocity.y *= -Float(ParticleSettings.bouncingCoefficient)
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
