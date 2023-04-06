
import Foundation
import simd

class Camera {
    let up = float3(0, 1, 0)
    var fieldOfView: Float = 60.0 // vertical, radians
    var eyeSpeed: Float = 2
    var radiansPerCursorPoint: Float = 0.0125
    var maximumPitchRadians: Float = (.pi / 2.0) * 0.98

    var eye = float3(0, 0, 0)
    var look = float3(0, 0, -1)

    var viewMatrix: matrix_float4x4 {
        var u = up
        var f = look
        let s = normalize(cross(f, u))
        u = normalize(cross(s, f))
        f = -f
        let t = float3(dot(s, -eye), dot(u, -eye), dot(f, -eye))
        let view = matrix_float4x4(float4(s.x, u.x, f.x, 0),
                                   float4(s.y, u.y, f.y, 0),
                                   float4(s.z, u.z, f.z, 0),
                                   float4(t.x, t.y, t.z, 1.0))
        return view
    }

    func projectionMatrix(viewportSize: CGSize) -> matrix_float4x4 {
        let aspectRatio = Float(viewportSize.width) / Float(viewportSize.height)
        return matrix_float4x4.perspective_projection_rh(fovyRadians: radians_from_degrees(fieldOfView),
                                                         aspectRatio: aspectRatio,
                                                         nearZ: 0.1,
                                                         farZ: 100.0)
    }

    func update(timestep: Float,
                mouseDelta: float2,
                forwardPressed: Bool,
                leftPressed: Bool,
                backwardPressed: Bool,
                rightPressed: Bool,
                upPressed: Bool,
                downPressed: Bool)
    {
        let across = normalize(cross(look, up))
        let forward = look

        let xMovement: Float = (leftPressed ? -1.0 : 0.0) + (rightPressed ? 1.0 : 0.0)
        let zMovement: Float = (backwardPressed ? -1.0 : 0.0) + (forwardPressed ? 1.0 : 0.0)
        let upDownMovement: Float = (upPressed ? 1.0 : 0.0) + (downPressed ? -1.0 : 0.0)
        
        let movementMagnitudeToXZPlane = hypot(xMovement, zMovement)
        let movementMagnitudeToUpDown = upDownMovement
        if movementMagnitudeToXZPlane > 1e-4 {
            let xzMovement = float3(xMovement * across.x + zMovement * forward.x,
                                    xMovement * across.y + zMovement * forward.y,
                                    xMovement * across.z + zMovement * forward.z)
            eye += normalize(xzMovement) * eyeSpeed * timestep
        }
        
        if abs(movementMagnitudeToUpDown) > 1e-4 {
            let yMovement = float3(0, upDownMovement, 0)
            eye += normalize(yMovement) * eyeSpeed * timestep
        }

        if mouseDelta.x != 0 {
            let yaw = -mouseDelta.x * radiansPerCursorPoint
            let yawRotation = matrix_float3x3.rotation(about: up, by: yaw)
            look = normalize(yawRotation * look)
        }

        if mouseDelta.y != 0 {
            let angleToUp: Float = acos(dot(look, up))
            let angleToDown: Float = acos(dot(look, -up))
            let maxPitch = max(0.0, angleToUp - (.pi / 2 - maximumPitchRadians))
            let minPitch = max(0.0, angleToDown - (.pi / 2 - maximumPitchRadians))
            var pitch = mouseDelta.y * radiansPerCursorPoint
            pitch = max(-minPitch, min(pitch, maxPitch))
            let pitchRotation = matrix_float3x3.rotation(about: across, by: pitch)
            look = normalize(pitchRotation * look)
        }
    }
}
