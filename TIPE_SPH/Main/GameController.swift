import MetalKit

class GameController: NSObject {
    // test
    var renderer: Renderer
    
    var particles: [Particle] = []
    static var particleBuffer: MTLBuffer!
    
    static var comboArr: [Combo] = []
    static var startIndices: [Int32] = .init(repeating: 0, count: Int(ParticleSettings.particleCount))

    var lastTime: Double = CFAbsoluteTimeGetCurrent()

    init(metalView: MTKView) {
        renderer = Renderer(metalView: metalView)
        
        super.init()
        
        metalView.device = Renderer.device
        metalView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        metalView.depthStencilPixelFormat = .depth32Float
        metalView.preferredFramesPerSecond = Settings.PreferredFrameRate
        metalView.delegate = self
        
        initParticles()
    }

    func initParticles() {
        let gridConstantX = (ParticleSettings.gridSize[0])/Float(ParticleSettings.gridPopulation[0])
        let gridConstantY = (ParticleSettings.gridSize[1])/Float(ParticleSettings.gridPopulation[1])
        let gridConstantZ = (ParticleSettings.gridSize[2])/Float(ParticleSettings.gridPopulation[2])

        var ID: UInt32 = 0
        for y in 0..<ParticleSettings.gridPopulation[1] {
            for x in 0..<ParticleSettings.gridPopulation[0] {
                for z in 0..<ParticleSettings.gridPopulation[2] {
                    ID += 1
                    let pos: SIMD3<Float> = .init(
                        Float(x)*gridConstantX+ParticleSettings.gridPosition[0]-ParticleSettings.gridSize[0]/2+Float.random(in: -ParticleSettings.spawnJigger...ParticleSettings.spawnJigger),
                        Float(y)*gridConstantY+ParticleSettings.gridPosition[1]-ParticleSettings.gridSize[1]/2+Float.random(in: -ParticleSettings.spawnJigger...ParticleSettings.spawnJigger),
                        Float(z)*gridConstantZ+ParticleSettings.gridPosition[2]-ParticleSettings.gridSize[2]/2+Float.random(in: -ParticleSettings.spawnJigger...ParticleSettings.spawnJigger))
                    particles.append(Particle(position: pos, oldPosition: pos, velocity: [0, 0, 0], acceleration: [0, 0, 0], forces: [0, 0, 0], color: [1, 1, 1], rho: 0, pressure: 0, density: 1, viscosity: 0))
                    GameController.comboArr.append(Combo(ID: ID, hashKey: 0))
                }
            }
        }
        GameController.particleBuffer = Renderer.device.makeBuffer(bytes: &particles, length: MemoryLayout<Particle>.stride*Int(ParticleSettings.particleCount))
    }
}

extension GameController: MTKViewDelegate {
    func mtkView(_: MTKView, drawableSizeWillChange _: CGSize) {}
    
    func draw(in view: MTKView) {
        let currentTime = CFAbsoluteTimeGetCurrent()
        var deltaTime = Float(currentTime-lastTime)
        lastTime = currentTime
        if Settings.fixedDeltaTime != 0 {
            deltaTime = Settings.fixedDeltaTime
        }
        renderer.render(view: view, deltaTime: deltaTime)
    }
}
