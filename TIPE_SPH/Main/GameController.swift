import MetalKit

class GameController : NSObject {
    //test
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
        let gridConstantX = ParticleSettings.gridSize[0]/Float(ParticleSettings.gridPopulation[0])
        let gridConstantY = ParticleSettings.gridSize[1]/Float(ParticleSettings.gridPopulation[1])
        let gridConstantZ = ParticleSettings.gridSize[2]/Float(ParticleSettings.gridPopulation[2])

        for y in 0..<ParticleSettings.gridPopulation[1] {
            for x in 0..<ParticleSettings.gridPopulation[0] {
                for z in 0..<ParticleSettings.gridPopulation[2] {
                    particles.append(Particle(position: [
                        Float(x)*gridConstantX+ParticleSettings.gridPosition[0]+Float.random(in: -ParticleSettings.spawnJigger...ParticleSettings.spawnJigger),
                        Float(y)*gridConstantY+ParticleSettings.gridPosition[1]+Float.random(in: -ParticleSettings.spawnJigger...ParticleSettings.spawnJigger),
                        Float(z)*gridConstantZ+ParticleSettings.gridPosition[2]+Float.random(in: -ParticleSettings.spawnJigger...ParticleSettings.spawnJigger)
                    ], velocity: [0, 0, 0], acceleration: [0, 0, 0], force: [0, 0, 0], pressure: 0, density: 1, viscosity: 0))
                }
            }
        }
        GameController.particleBuffer = Renderer.device.makeBuffer(bytes: &particles, length: MemoryLayout<Particle>.stride*Int(ParticleSettings.particleCount))
    
    }
    
    
    
    
}

extension GameController : MTKViewDelegate{
    func mtkView(_ view: MTKView, drawableSizeWillChange _: CGSize) {}
    
    func draw(in view: MTKView) {
        
        let currentTime = CFAbsoluteTimeGetCurrent()
        let deltaTime = Float(currentTime - lastTime)
        lastTime = currentTime
        renderer.render(view: view, deltaTime: deltaTime)
        
        
        
    }
}
