import MetalKit

class MetalContext {
    static let shared = MetalContext()

    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let bufferAllocator: MTKMeshBufferAllocator
    let textureLoader: MTKTextureLoader

    init(device: MTLDevice? = nil) {
        self.device = device ?? MTLCreateSystemDefaultDevice()!
        self.commandQueue = self.device.makeCommandQueue()!
        self.bufferAllocator = MTKMeshBufferAllocator(device: self.device)
        self.textureLoader = MTKTextureLoader(device: self.device)
    }

    func makeTexture(named name: String, generateMipmaps: Bool = true) throws -> MTLTexture {
        let options : [MTKTextureLoader.Option : Any] = [
            .textureUsage: MTLTextureUsage.shaderRead.rawValue,
            .textureStorageMode: MTLStorageMode.private.rawValue,
            .generateMipmaps : generateMipmaps
        ]
        return try textureLoader.newTexture(name: name, scaleFactor: 1.0, bundle: nil, options: options)
    }
}
