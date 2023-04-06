
import Darwin
import simd

typealias float2 = SIMD2<Float>
typealias float3 = SIMD3<Float>
typealias float4 = SIMD4<Float>

func radians_from_degrees(_ degrees: Float) -> Float {
    return (degrees / 180) * .pi
}

extension matrix_float3x3 {
    static func rotation(about axis: float3, by angle: Float) -> matrix_float3x3 {
        let c = cos(angle)
        let s = sin(angle)
        let x = float3(c + (1.0 - c) * axis.x * axis.x, (1.0 - c) * axis.x * axis.y + s * axis.z, (1.0 - c) * axis.x * axis.z - s * axis.y)
        let y = float3((1.0 - c) * axis.x * axis.y - s * axis.z, c + (1.0 - c) * axis.y * axis.y, (1.0 - c) * axis.y * axis.z + s * axis.x)
        let z = float3((1.0 - c) * axis.x * axis.z + s * axis.y, (1.0 - c) * axis.y * axis.z - s * axis.x, c + (1.0 - c) * axis.z * axis.z)

        return matrix_float3x3(x, y, z)
    }
}

extension matrix_float4x4 {
    init(translationBy t: float3)
    {
        self.init(float4(1, 0, 0, 0),
                  float4(0, 1, 0, 0),
                  float4(0, 0, 1, 0),
                  float4(   t   , 1))
    }

    static func perspective_projection_rh(fovyRadians fovy: Float,
                                          aspectRatio: Float,
                                          nearZ: Float,
                                          farZ: Float) -> matrix_float4x4
    {
        let ys = 1 / tan(fovy * 0.5)
        let xs = ys / aspectRatio
        let zs = farZ / (nearZ - farZ)
        let zt = zs * nearZ
        return matrix_float4x4(float4(xs,  0, 0,   0),
                               float4( 0, ys, 0,   0),
                               float4( 0,  0, zs, -1),
                               float4( 0,  0, zt,  0))
    }
}
