
import Foundation
import MetalKit

class TessellatedMeshRenderer : MeshRenderer {
    let context: MetalContext

    let mesh: TessellatedMesh
    var edgeTessellationFactor: Float = 1.0
    var insideTessellationFactor: Float = 1.0
    var drawAsWireframe: Bool = false
    var spherify: Bool = true

    private var computePipelineState: MTLComputePipelineState!
    private var renderPipelineState: MTLRenderPipelineState!

    init(mesh: TessellatedMesh, framebuffer: FramebufferDescriptor, context: MetalContext) {
        self.mesh = mesh
        self.context = context
        do {
            try makePipelines(framebuffer)
        } catch {
            print("Error occurred when preparing mesh renderer: \(error)")
        }
    }

    func makePipelines(_ framebuffer: FramebufferDescriptor) throws {
        let library = context.device.makeDefaultLibrary()!

        let vertexFunction = library.makeFunction(name: mesh.postTessellationVertexFunctionName)!
        let fragmentFunction = library.makeFunction(name: "fragment_subdiv")!

        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.vertexFunction = vertexFunction
        renderPipelineDescriptor.fragmentFunction = fragmentFunction

        renderPipelineDescriptor.vertexDescriptor = mesh.vertexDescriptor

        renderPipelineDescriptor.tessellationPartitionMode = .pow2
        renderPipelineDescriptor.tessellationFactorStepFunction = .perPatch
        renderPipelineDescriptor.tessellationOutputWindingOrder = .counterClockwise
        renderPipelineDescriptor.tessellationControlPointIndexType = mesh.controlPointIndexType

        renderPipelineDescriptor.colorAttachments[0].pixelFormat = framebuffer.colorPixelFormat
        renderPipelineDescriptor.depthAttachmentPixelFormat = framebuffer.depthStencilPixelFormat
        renderPipelineDescriptor.stencilAttachmentPixelFormat = framebuffer.depthStencilPixelFormat
        renderPipelineDescriptor.rasterSampleCount = framebuffer.rasterSampleCount

        renderPipelineState = try context.device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)

        let computeFunction = library.makeFunction(name: mesh.tessellationFactorFunctionName)!
        computePipelineState = try context.device.makeComputePipelineState(function: computeFunction)
    }

    func update(_ commandBuffer: MTLCommandBuffer) {
        let computeCommandEncoder = commandBuffer.makeComputeCommandEncoder()!
        computeCommandEncoder.pushDebugGroup("Compute Tessellation Factors")
        computeCommandEncoder.setComputePipelineState(computePipelineState)
        computeCommandEncoder.setBuffer(mesh.tessellationFactorBuffer, offset: 0, index: 0)
        var factors = float2(edgeTessellationFactor, insideTessellationFactor)
        computeCommandEncoder.setBytes(&factors, length: MemoryLayout<float2>.stride, index: 1)
        let threadgroupSize = MTLSize(width: computePipelineState.threadExecutionWidth, height: 1, depth: 1)
        // Non-uniform dispatch grids are supported on all Macs and A11+, so we assume they're available here.
        let threadCount = MTLSize(width: mesh.patchCount, height: 1, depth: 1)
        computeCommandEncoder.dispatchThreads(threadCount, threadsPerThreadgroup: threadgroupSize)
        computeCommandEncoder.popDebugGroup()
        computeCommandEncoder.endEncoding()
    }

    func draw(in renderCommandEncoder: MTLRenderCommandEncoder) {
        renderCommandEncoder.pushDebugGroup("Draw Patches")
        renderCommandEncoder.setTriangleFillMode(drawAsWireframe ? .lines : .fill)
        renderCommandEncoder.setRenderPipelineState(renderPipelineState)
        renderCommandEncoder.setVertexBuffer(mesh.controlPointBuffer.buffer, offset: mesh.controlPointBuffer.offset, index: 0)
        var modelMatrix = mesh.modelTransform
        renderCommandEncoder.setVertexBytes(&modelMatrix, length: MemoryLayout<float4x4>.stride, index: 2)
        renderCommandEncoder.setVertexBytes(&spherify, length: MemoryLayout<Bool>.stride, index: 3)
        renderCommandEncoder.setTessellationFactorBuffer(mesh.tessellationFactorBuffer,
                                                         offset: mesh.tessellationFactorBufferOffset,
                                                         instanceStride: 0)
        if let controlPointIndexBuffer = mesh.controlPointIndexBuffer {
            renderCommandEncoder.drawIndexedPatches(numberOfPatchControlPoints: mesh.controlPointsPerPatch,
                                                    patchStart: 0,
                                                    patchCount: mesh.patchCount,
                                                    patchIndexBuffer: nil,
                                                    patchIndexBufferOffset: 0,
                                                    controlPointIndexBuffer: controlPointIndexBuffer.buffer,
                                                    controlPointIndexBufferOffset:controlPointIndexBuffer.offset,
                                                    instanceCount: 1,
                                                    baseInstance: 0)
        } else {
            renderCommandEncoder.drawPatches(numberOfPatchControlPoints: mesh.controlPointsPerPatch,
                                             patchStart: 0,
                                             patchCount: mesh.patchCount,
                                             patchIndexBuffer: nil,
                                             patchIndexBufferOffset: 0,
                                             instanceCount: 1,
                                             baseInstance: 0)
        }
        renderCommandEncoder.popDebugGroup()
    }
}
