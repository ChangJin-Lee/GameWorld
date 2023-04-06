import Cocoa
import MetalKit

enum KeyCode : Int {
    case A = 0x00
    case S = 0x01
    case D = 0x02
    case W = 0x0D
    case Q = 0xC
    case E = 0xE
}

class ViewController: NSViewController {
    @IBOutlet weak var tessellationFactorLabel: NSTextField!
    @IBOutlet weak var tessellationFactorSlider: NSSlider!
    @IBOutlet weak var wireframeCheckbox: NSButton!
    @IBOutlet weak var spherifyCheckbox: NSButton!

    var renderer: SceneRenderer!
    var meshRenderers = [TessellatedMeshRenderer]()

    private var keysPressed = [Bool](repeating: false, count: Int(UInt16.max))
    private var previousMousePoint = NSPoint.zero
    private var currentMousePoint = NSPoint.zero

    private var appearanceObservation: NSKeyValueObservation? = nil

    var mtkView: MTKView {
        guard let mtkView = self.view as? MTKView else {
            fatalError("View controller's view in Storyboard is not an MTKView")
        }
        return mtkView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let context = MetalContext(device: mtkView.preferredDevice)
        let framebuffer = FramebufferDescriptor()

        mtkView.device = context.device
        mtkView.colorPixelFormat = framebuffer.colorPixelFormat
        mtkView.depthStencilPixelFormat = framebuffer.depthStencilPixelFormat
        mtkView.sampleCount = framebuffer.rasterSampleCount
        updateClearColor()

        renderer = SceneRenderer(context: context)
        mtkView.delegate = renderer

        let boxMesh = TessellatedMesh(named: "box", context: context)!
        boxMesh.modelTransform = float4x4(translationBy: float3(-2, 0, 0))
        let icoMesh = TessellatedMesh(named: "ico", context: context)!
        icoMesh.modelTransform = float4x4(translationBy: float3(2, 0, 0))

        let boxRenderer = TessellatedMeshRenderer(mesh: boxMesh, framebuffer: framebuffer, context: context)
        let icoRenderer = TessellatedMeshRenderer(mesh: icoMesh, framebuffer: framebuffer, context: context)
        meshRenderers = [boxRenderer, icoRenderer]

        renderer.meshRenderers.append(contentsOf: meshRenderers)

        let frameDuration = 1 / 60.0
        Timer.scheduledTimer(withTimeInterval: frameDuration, repeats: true) { timer in
            self.updateFlyCamera(timestep: Float(frameDuration))
        }

        appearanceObservation = mtkView.observe(\.effectiveAppearance) { (app, _) in
            self.updateClearColor()
        }
    }

    override func viewDidAppear() {
        self.view.window?.makeFirstResponder(self)
    }

    override func becomeFirstResponder() -> Bool {
        return true
    }

    private let linearSpace = NSColorSpace(cgColorSpace: CGColorSpace(name: CGColorSpace.linearSRGB)!)!
    private func updateClearColor() {
        // Set the clear color of the view to match the expected background of the current theme
        mtkView.withEffectiveAppearance {
            let clear = NSColor.windowBackgroundColor.usingColorSpace(linearSpace)!
            mtkView.clearColor = MTLClearColor(red: clear.redComponent,
                                               green: clear.greenComponent,
                                               blue: clear.blueComponent,
                                               alpha: 1.0)
        }
    }

    @IBAction func tessellationFactorSliderValueDidChange(_ sender: Any) {
        // The tessellation factor slider goes from 0 to 1, so we remap
        // the value in log space and find the nearest higher power of two,
        // which we then use as the actual tessellation factor(s).
        let maxFactor: Float = 16.0
        let logMax = log2(maxFactor)
        let edgePower = ceil(tessellationFactorSlider.floatValue * logMax)
        let insidePower = ceil(tessellationFactorSlider.floatValue * logMax)
        let edgeFactor = pow(2, edgePower)
        let insideFactor = pow(2, insidePower)
        for mesh in meshRenderers {
            mesh.edgeTessellationFactor = edgeFactor
            mesh.insideTessellationFactor = insideFactor
        }
        tessellationFactorLabel.stringValue = "Tessellation factors: [\(edgeFactor), \(insideFactor)]"
    }

    @IBAction func spherifyCheckboxValueDidChange(_ sender: Any) {
        for mesh in meshRenderers {
            mesh.spherify = (spherifyCheckbox.state == .on)
        }
    }

    @IBAction func wireframeCheckboxValueDidChange(_ sender: Any) {
        for mesh in meshRenderers {
            mesh.drawAsWireframe = (wireframeCheckbox.state == .on)
        }
    }

    func updateFlyCamera(timestep: Float) {
        let cursorDeltaX = Float(currentMousePoint.x - previousMousePoint.x)
        let cursorDeltaY = Float(currentMousePoint.y - previousMousePoint.y)

        let forwardPressed = keysPressed[KeyCode.W.rawValue]
        let backwardPressed = keysPressed[KeyCode.S.rawValue]
        let leftPressed = keysPressed[KeyCode.A.rawValue]
        let rightPressed = keysPressed[KeyCode.D.rawValue]
        let upPressed = keysPressed[KeyCode.E.rawValue]
        let downPressed = keysPressed[KeyCode.Q.rawValue]

        renderer.camera.update(timestep: timestep,
                               mouseDelta: float2(cursorDeltaX, cursorDeltaY),
                               forwardPressed: forwardPressed, leftPressed: leftPressed,
                               backwardPressed: backwardPressed, rightPressed: rightPressed,
                               upPressed: upPressed, downPressed: downPressed)

        previousMousePoint = currentMousePoint
    }

    override func mouseDown(with event: NSEvent) {
        let mouseLocation = self.view.convert(event.locationInWindow, from: nil)
        currentMousePoint = mouseLocation
        previousMousePoint = mouseLocation
    }

    override func mouseDragged(with event: NSEvent) {
        let mouseLocation = self.view.convert(event.locationInWindow, from: nil)
         previousMousePoint = currentMousePoint
         currentMousePoint = mouseLocation
    }

    override func mouseUp(with event: NSEvent) {
        let mouseLocation = self.view.convert(event.locationInWindow, from: nil)
        previousMousePoint = mouseLocation
        currentMousePoint = mouseLocation
    }

    override func keyDown(with event: NSEvent) {
        keysPressed[Int(event.keyCode)] = true
    }

    override func keyUp(with event: NSEvent) {
        keysPressed[Int(event.keyCode)] = false
    }
}
