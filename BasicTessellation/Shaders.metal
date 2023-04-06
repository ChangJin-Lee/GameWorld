
#include <metal_stdlib>
using namespace metal;

struct FrameConstants {
    float4x4 viewProjectionMatrix;
};

struct MeshConstants {
    float4x4 modelMatrix;
};

struct ControlPoint {
    float3 position [[attribute(0)]];
    float3 normal   [[attribute(1)]];
};

struct PatchIn {
    patch_control_point<ControlPoint> controlPoints;
};

struct VertexOut {
    float4 position [[position]];
    float3 worldNormal;
};

/// Calculate a value by bilinearly interpolating among four control points.
/// The four values c00, c01, c10, and c11 represent, respectively, the
/// upper-left, upper-right, lower-left, and lower-right points of a quad
/// that is parameterized by a normalized space that runs from (0, 0)
/// in the upper left to (1, 1) in the lower right (similar to Metal's texture
/// space). The vector `uv` contains the influence of the points along the
/// x and y axes.
template <typename T>
T bilerp(T c00, T c01, T c10, T c11, float2 uv) {
    T c0 = mix(c00, c01, T(uv[0]));
    T c1 = mix(c10, c11, T(uv[0]));
    return mix(c0, c1, T(uv[1]));
}

/// Calculate a value by interpolating among three control points. The
/// vector `bary` contains barycentric weights that sum to 1 and determine
/// the contribution of each control point value to the output value.
template <typename T>
T baryinterp(T c0, T c1, T c2, float3 bary) {
    return c0 * bary[0] + c1 * bary[1] + c2 * bary[2];
}

kernel void compute_tess_factors_quad(device MTLQuadTessellationFactorsHalf *patchFactorsArray [[buffer(0)]],
                                      constant float2 &factors [[buffer(1)]],
                                      uint patchIndex [[thread_position_in_grid]])
{
    device MTLQuadTessellationFactorsHalf &patchFactors = patchFactorsArray[patchIndex];
    patchFactors.edgeTessellationFactor[0] = factors[0];
    patchFactors.edgeTessellationFactor[1] = factors[0];
    patchFactors.edgeTessellationFactor[2] = factors[0];
    patchFactors.edgeTessellationFactor[3] = factors[0];
    patchFactors.insideTessellationFactor[0] = factors[1];
    patchFactors.insideTessellationFactor[1] = factors[1];
}

kernel void compute_tess_factors_tri(device MTLTriangleTessellationFactorsHalf *patchFactorsArray [[buffer(0)]],
                                     constant float2 &factors [[buffer(1)]],
                                     uint patchIndex [[thread_position_in_grid]])
{
    device MTLTriangleTessellationFactorsHalf &patchFactors = patchFactorsArray[patchIndex];
    patchFactors.edgeTessellationFactor[0] = factors[0];
    patchFactors.edgeTessellationFactor[1] = factors[0];
    patchFactors.edgeTessellationFactor[2] = factors[0];
    patchFactors.insideTessellationFactor = factors[1];
}

static VertexOut calculateTessellatedVertex(constant float4x4 &modelMatrix,
                                            constant float4x4 &viewProjectionMatrix,
                                            float3 position,
                                            float3 normal,
                                            float radius,
                                            bool spherify)
{
    float3 modelNormal = spherify ? normalize(position) : normal;
    float3 modelPosition = spherify ? radius * modelNormal : position;

    float3 worldNormal = (modelMatrix * float4(modelNormal, 0.0f)).xyz;
    float4 worldPosition = modelMatrix * float4(modelPosition, 1.0f);

    VertexOut out;
    out.position = viewProjectionMatrix * worldPosition;
    out.worldNormal = worldNormal;
    return out;
}

[[patch(quad, 4)]]
vertex VertexOut vertex_subdiv_quad(PatchIn patch                  [[stage_in]],
                                    constant FrameConstants &frame [[buffer(1)]],
                                    constant MeshConstants &mesh   [[buffer(2)]],
                                    constant bool &spherify        [[buffer(3)]],
                                    float2 positionInPatch         [[position_in_patch]])
{
    float3 p00 = patch.controlPoints[0].position;
    float3 p01 = patch.controlPoints[1].position;
    float3 p10 = patch.controlPoints[3].position;
    float3 p11 = patch.controlPoints[2].position;
    float3 position = bilerp(p00, p01, p10, p11, positionInPatch);

    // Take the normal of the first control point to be representative of the
    // entire patch. This produces a faceted appearance by design, which is
    // overridden by a smoother normal when spherization is enabled.
    float3 normal = patch.controlPoints[0].normal;

    // Assuming all control points are equidistant from the patch center,
    // we take the radius of the mesh to be the length of the first point.
    float radius = length(patch.controlPoints[0].position);

    return calculateTessellatedVertex(mesh.modelMatrix, frame.viewProjectionMatrix, position, normal, radius, spherify);
}

[[patch(triangle, 3)]]
vertex VertexOut vertex_subdiv_tri(PatchIn patch                  [[stage_in]],
                                   constant FrameConstants &frame [[buffer(1)]],
                                   constant MeshConstants &mesh   [[buffer(2)]],
                                   constant bool &spherify        [[buffer(3)]],
                                   float3 positionInPatch         [[position_in_patch]])
{
    float3 p0 = patch.controlPoints[0].position;
    float3 p1 = patch.controlPoints[1].position;
    float3 p2 = patch.controlPoints[2].position;
    float3 position = baryinterp(p0, p1, p2, positionInPatch);

    float3 normal = patch.controlPoints[0].normal;

    float radius = length(patch.controlPoints[0].position);

    return calculateTessellatedVertex(mesh.modelMatrix, frame.viewProjectionMatrix, position, normal, radius, spherify);
}

fragment half4 fragment_subdiv(VertexOut in [[stage_in]],
                               texture2d<half, access::sample> tex [[texture(0)]])
{
    constexpr sampler linearSampler(filter::linear, address::clamp_to_edge);

    float3 L = normalize(float3(0.5, 0.5, 1)); // Direction toward light in world space
    float diffuseIntensity = saturate(dot(normalize(in.worldNormal), L));
    half4 color = tex.sample(linearSampler, float2(diffuseIntensity, 0.0f));
    return color;
}
