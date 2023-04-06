
import Metal
import MetalKit

struct FramebufferDescriptor {
    var colorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb
    var depthStencilPixelFormat = MTLPixelFormat.depth32Float_stencil8
    var rasterSampleCount: Int = 4
}

protocol MeshRenderer : AnyObject {
    func update(_ commandBuffer: MTLCommandBuffer)
    func draw(in renderCommandEncoder: MTLRenderCommandEncoder)
}

let MaxPendingFrameCount = 3
let FrameConstantStride = 256

class SceneRenderer: NSObject, MTKViewDelegate {
    let context: MetalContext

    let camera = Camera()
    var meshRenderers = [MeshRenderer]()

    private var depthState: MTLDepthStencilState!
    private var constantsBuffer: MTLBuffer!
    private var colorMap: MTLTexture!

    private let frameCompletionSemaphore = DispatchSemaphore(value: MaxPendingFrameCount)
    private var frameConstantsOffset = 0
    private var constantBufferRegionIndex = 0

    init(context: MetalContext) {
        self.context = context
        super.init()
        do {
            try makeResources()
        } catch {
            print("Error occurred when loading resources: \(error)")
        }
        camera.eye = float3(0, 0, 6)
    }

    func makeResources() throws {
        let uniformBufferSize = FrameConstantStride * MaxPendingFrameCount
        constantsBuffer = context.device.makeBuffer(length:uniformBufferSize, options:.storageModeShared)!
        constantsBuffer.label = "Frame Constants"

        colorMap = try context.makeTexture(named: "plasma")

        let depthStateDescriptor = MTLDepthStencilDescriptor()
        depthStateDescriptor.depthCompareFunction = .less
        depthStateDescriptor.isDepthWriteEnabled = true
        depthState = context.device.makeDepthStencilState(descriptor:depthStateDescriptor)!
    }

    func draw(in view: MTKView) {
        _ = frameCompletionSemaphore.wait(timeout: DispatchTime.now() + 1.0)

        guard let commandBuffer = context.commandQueue.makeCommandBuffer() else { return }
        let semaphore = frameCompletionSemaphore
        commandBuffer.addCompletedHandler { _ in
            semaphore.signal()
        }

        for meshRenderer in meshRenderers {
            meshRenderer.update(commandBuffer)
        }

        let viewMatrix = camera.viewMatrix
        let projectionMatrix = camera.projectionMatrix(viewportSize: view.drawableSize)
        var viewProjectionMatrix = projectionMatrix * viewMatrix

        let frameConstantsOffset = FrameConstantStride * constantBufferRegionIndex
        constantsBuffer.write(value: &viewProjectionMatrix, at: frameConstantsOffset)

        guard let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
        guard let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)  else { return }
        renderCommandEncoder.setDepthStencilState(depthState)
        renderCommandEncoder.setFrontFacing(.counterClockwise)
        renderCommandEncoder.setCullMode(.back)
        renderCommandEncoder.setVertexBuffer(constantsBuffer, offset: frameConstantsOffset, index: 1)
        renderCommandEncoder.setFragmentTexture(colorMap, index: 0)
        for meshRenderer in meshRenderers {
            meshRenderer.draw(in: renderCommandEncoder)
        }
        renderCommandEncoder.endEncoding()

        if let drawable = view.currentDrawable {
            commandBuffer.present(drawable)
        }
        commandBuffer.commit()

        constantBufferRegionIndex = (constantBufferRegionIndex + 1) % MaxPendingFrameCount
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    }
}
