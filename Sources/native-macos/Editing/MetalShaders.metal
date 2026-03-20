//
//  MetalShaders.metal
//  OpenScreen
//
// Shaders for video rendering pipeline

#include <metal_stdlib>
using namespace metal;

// Vertex shader for simple quad rendering
vertex float4 video_vertex_shader(uint vertexID [[vertex_id]]) {
    // Full-screen quad: triangle strip with 4 vertices
    float2 positions[4] = {
        float2(-1.0, -1.0),  // Bottom-left
        float2( 1.0, -1.0),  // Bottom-right
        float2(-1.0,  1.0),  // Top-left
        float2( 1.0,  1.0)   // Top-right
    };

    return float4(positions[vertexID], 0.0, 1.0);
}

// Fragment shader for video rendering
fragment float4 video_fragment_shader(
    float4 in [[position]],
    texture2d<float> videoTexture [[texture(0)]],
    sampler texSampler [[sampler(0)]]
) {
    // Sample center of texture (will be fullscreen quad)
    float2 texCoord = in.xy * 0.5 + 0.5;
    float4 color = videoTexture.sample(texSampler, texCoord);

    return color;
}

// Vertex data for textured rendering
struct VertexIn {
    float2 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord [[user(texCoord)]];
};

// Textured vertex shader
vertex VertexOut textured_vertex_shader(VertexIn in [[stage_in]]) {
    VertexOut out;
    out.position = float4(in.position, 0.0, 1.0);
    out.texCoord = in.texCoord;
    return out;
}
