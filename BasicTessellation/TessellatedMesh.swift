
import MetalKit
import ModelIO

func tessellationControlPointIndexType(for submesh: MDLSubmesh) -> MTLTessellationControlPointIndexType {
    switch submesh.indexType {
    case .uint16:
        return .uint16
    case .uint32:
        return .uint32
    default:
        return .none
    }
}

func controlPointCount(for geometryType: MDLGeometryType) -> Int {
    switch geometryType {
    case .triangles:
        return 3
    case .quads:
        return 4
    default:
        fatalError("Unsupported geometry type for tessellated mesh: \(geometryType)")
    }
}

class TessellatedMesh {
    let patchCount: Int

    let controlPointsPerPatch: Int

    let controlPointBuffer: MTKMeshBuffer

    let controlPointIndexBuffer: MTKMeshBuffer?
    let controlPointIndexType: MTLTessellationControlPointIndexType

    let tessellationFactorBuffer: MTLBuffer
    let tessellationFactorBufferOffset: Int

    let tessellationFactorFunctionName: String
    let postTessellationVertexFunctionName: String

    var modelTransform = matrix_identity_float4x4

    private static let mdlVertexDescriptor: MDLVertexDescriptor = {
        let vertexDescriptor = MDLVertexDescriptor()
        vertexDescriptor.attributes_[0].name = MDLVertexAttributePosition
        vertexDescriptor.attributes_[0].format = .float3
        vertexDescriptor.attributes_[0].offset = 0
        vertexDescriptor.attributes_[0].bufferIndex = 0
        vertexDescriptor.attributes_[1].name = MDLVertexAttributeNormal
        vertexDescriptor.attributes_[1].format = .float3
        vertexDescriptor.attributes_[1].offset = MemoryLayout<Float>.stride * 3
        vertexDescriptor.attributes_[1].bufferIndex = 0
        vertexDescriptor.layouts_[0].stride = MemoryLayout<Float>.stride * 6
        return vertexDescriptor
    }()

    var vertexDescriptor: MTLVertexDescriptor {
        let vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(TessellatedMesh.mdlVertexDescriptor)!
        // Set properties of our vertex buffer layout not supplied by ModelIO
        // appropriately for tessellated drawing
        vertexDescriptor.layouts[0].stepRate = 1
        vertexDescriptor.layouts[0].stepFunction = .perPatchControlPoint
        return vertexDescriptor
    }

    init?(named name: String, context: MetalContext) {
        guard let assetURL = Bundle.main.url(forResource: name, withExtension: "obj") else {
            print("Couldn't find OBJ asset in main bundle")
            return nil
        }

        var error: NSError?
        let asset = MDLAsset(url: assetURL,
                             vertexDescriptor: TessellatedMesh.mdlVertexDescriptor,
                             bufferAllocator: context.bufferAllocator,
                             preserveTopology: true,
                             error: &error)

        guard let mesh = asset.childObjects(of: MDLMesh.self).first as? MDLMesh else {
            print("Couldn't find mesh in OBJ asset")
            return nil
        }

        guard let submesh = mesh.submeshes?.firstObject as? MDLSubmesh else {
            print("Couldn't find submesh in mesh")
            return nil
        }

        if !((submesh.geometryType == .triangles) || (submesh.geometryType == .quads)) {
            print("Tessellated mesh can only be created from a mesh with uniform triangle or quad topology")
            return nil
        }

        controlPointsPerPatch = controlPointCount(for: submesh.geometryType)
        patchCount = mesh.vertexCount / controlPointsPerPatch
        controlPointBuffer = mesh.vertexBuffers[0] as! MTKMeshBuffer

        controlPointIndexBuffer = nil
        controlPointIndexType = .none
        // Substitute the two lines below for the two lines above if
        // you'd like to see indexed control points in action.
        // controlPointIndexBuffer = submesh.indexBuffer as? MTKMeshBuffer
        // controlPointIndexType = tessellationControlPointIndexType(for: submesh)

        let tessellationFactorSize = (controlPointsPerPatch == 4) ?
            MemoryLayout<MTLQuadTessellationFactorsHalf>.stride :
            MemoryLayout<MTLTriangleTessellationFactorsHalf>.stride
        tessellationFactorBuffer = context.device.makeBuffer(length: tessellationFactorSize * patchCount,
                                                             options: [.storageModePrivate])!
        tessellationFactorBufferOffset = 0

        if (controlPointsPerPatch == 4) {
            tessellationFactorFunctionName = "compute_tess_factors_quad"
            postTessellationVertexFunctionName = "vertex_subdiv_quad"
        } else {
            tessellationFactorFunctionName = "compute_tess_factors_tri"
            postTessellationVertexFunctionName = "vertex_subdiv_tri"
        }
    }
}
