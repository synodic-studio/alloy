#include <metal_stdlib>
using namespace metal;

struct alignas(16) BinaryThresholdParams {
    float threshold;  // Threshold value (0.0-1.0) - 4 bytes
    uint strategy;    // Grayscale conversion strategy (0-7) - 4 bytes
    float _padding0;  // Padding to align to 16 bytes - 4 bytes
    float _padding1;  // Padding to align to 16 bytes - 4 bytes
};

// convertToGrayscale is defined in Grayscale.metal (same compilation unit)
// adjustLevels is NOT used here — we want a hard binary comparison

kernel void binaryThreshold(
    texture2d<uint, access::read> inputTexture [[texture(0)]],
    texture2d<uint, access::write> outputTexture [[texture(1)]],
    constant BinaryThresholdParams& params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    // Early exit if we're outside the output bounds
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }

    // Read input pixel
    uint4 inputColor = inputTexture.read(gid);

    // Convert to normalized float values (0.0 - 1.0)
    float4 rgba = float4(inputColor) / 255.0;

    // Apply grayscale conversion strategy
    float grayscaleValue = convertToGrayscale(rgba, params.strategy);

    // Hard binary threshold — no ramp, no interpolation.
    // Any pixel >= threshold becomes pure white (255); everything else is pure black (0).
    uint outputValue = grayscaleValue >= params.threshold ? 255 : 0;

    // Write pure white or pure black (preserve alpha from input for masking)
    outputTexture.write(uint4(outputValue, outputValue, outputValue, inputColor.a), gid);
}
