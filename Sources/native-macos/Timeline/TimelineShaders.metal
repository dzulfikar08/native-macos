//
//  TimelineShaders.metal
//  OpenScreen
//
//  Metal shaders for timeline rendering including waveform visualization,
//  time ruler, and playback indicators.
//

#include <metal_stdlib>
using namespace metal;

// Vertex shader for timeline rendering
struct Vertex {
    float2 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

// Uniform buffer for timeline state
struct TimelineUniforms {
    float2 viewportSize;
    float2 contentOffset;
    float contentScale;
    float currentTime;
    float waveformAmplitude;
    float4 playheadColor;
    float4 gridColor;
    float4 waveformColor;
};

// Vertex output to fragment shader
struct RasterizerData {
    float4 position [[position]];
    float2 texCoord;
    float4 color;
};

// Vertex shader
vertex RasterizerData timeline_vertex(Vertex in [[stage_in]],
                                      constant TimelineUniforms &uniforms [[buffer(1)]]) {
    RasterizerData out;

    // Convert pixel coordinates to clip space
    float2 pixelPosition = in.position * uniforms.contentScale + uniforms.contentOffset;
    float2 clipSpace = (pixelPosition / uniforms.viewportSize) * 2.0 - 1.0;
    out.position = float4(clipSpace * float2(1.0, -1.0), 0.0, 1.0);
    out.texCoord = in.texCoord;

    // Color based on texture coordinates (will be overridden in fragment)
    out.color = float4(1.0);

    return out;
}

// Fragment shader for waveform rendering
fragment float4 waveform_fragment(RasterizerData in [[stage_in]],
                                  constant TimelineUniforms &uniforms [[buffer(1)]],
                                  texture2d<float> waveformTexture [[texture(0)]]) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);

    // Sample waveform data
    float4 waveformSample = waveformTexture.sample(textureSampler, in.texCoord);

    // Apply waveform amplitude
    float intensity = waveformSample.r * uniforms.waveformAmplitude;

    // Mix with waveform color
    float4 color = mix(uniforms.gridColor, uniforms.waveformColor, intensity);

    return color;
}

// Fragment shader for playhead
fragment float4 playhead_fragment(RasterizerData in [[stage_in]],
                                  constant TimelineUniforms &uniforms [[buffer(1)]]) {
    return uniforms.playheadColor;
}

// Fragment shader for time ruler grid
fragment float4 grid_fragment(RasterizerData in [[stage_in]],
                              constant TimelineUniforms &uniforms [[buffer(1)]]) {
    return uniforms.gridColor;
}

// Fragment shader for solid fill regions
fragment float4 solid_fragment(RasterizerData in [[stage_in]],
                               constant TimelineUniforms &uniforms [[buffer(1)]]) {
    return in.color;
}

// Compute shader for waveform generation
kernel void generate_waveform(texture2d<float, access::write> output [[texture(0)]],
                             const device float *audioData [[buffer(0)]],
                             constant uint &audioSampleCount [[buffer(1)]],
                             constant uint &samplesPerPixel [[buffer(2)]],
                             uint2 gid [[thread_position_in_grid]]) {
    // Ensure we're within bounds
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) {
        return;
    }

    // Calculate RMS for this pixel column
    uint startSample = gid.x * samplesPerPixel;
    uint endSample = min(startSample + samplesPerPixel, audioSampleCount);

    float sumSquares = 0.0;
    uint sampleCount = 0;

    for (uint i = startSample; i < endSample; i++) {
        float sample = audioData[i];
        sumSquares += sample * sample;
        sampleCount++;
    }

    float rms = sampleCount > 0 ? sqrt(sumSquares / float(sampleCount)) : 0.0;

    // Store RMS in red channel
    float4 color = float4(rms, 0.0, 0.0, 1.0);
    output.write(color, gid);
}
