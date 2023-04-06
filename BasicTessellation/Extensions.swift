import ModelIO
import MetalKit

extension MTLBuffer {
    // Write a value to this buffer at the specified offset.
    // T must be a trivial type, and offset must honor any alignment requirements.
    func write<T>(value: inout T, at offset: Int) {
        contents().advanced(by: offset).copyMemory(from: &value, byteCount: MemoryLayout<T>.size)
    }
}

// Attributes and layouts are bridged to Swift as [Any], which isn't very ergonomic,
// so we provide our own strongly-typed accessors.
extension MDLVertexDescriptor {
    var attributes_: [MDLVertexAttribute] {
        return attributes as! [MDLVertexAttribute]
    }

    var layouts_: [MDLVertexBufferLayout] {
        return layouts as! [MDLVertexBufferLayout]
    }
}

extension NSAppearanceCustomization {
    // Runs the specified closure in the context of the receiver's effective
    // appearance. This enables retrieving system and asset catalog colors
    // with light or dark mode variations, among other things.
    func withEffectiveAppearance(_ closure: () -> ()) {
        if #available(macOS 11.0, *) {
            effectiveAppearance.performAsCurrentDrawingAppearance {
                closure()
            }
        } else {
            let previousAppearance = NSAppearance.current
            NSAppearance.current = effectiveAppearance
            defer {
                NSAppearance.current = previousAppearance
            }
            closure()
        }
    }
}
