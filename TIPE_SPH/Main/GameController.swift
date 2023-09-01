import MetalKit

class GameController : NSObject {
    
    var renderer : Renderer
    
    init(metalView : MTKView){
        
        
        renderer = Renderer(metalView: metalView)
        
        super.init()
        
        metalView.device = Renderer.device
        metalView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        metalView.depthStencilPixelFormat = .depth32Float
        metalView.delegate = self
        
        
    }
    
    
    
}

extension GameController : MTKViewDelegate{
    func mtkView(_ view: MTKView, drawableSizeWillChange _: CGSize) {}
    
    func draw(in view: MTKView) {
        
        renderer.render(view: view)
        
        
        
    }
    
    
    
}
