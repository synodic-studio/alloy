#include <metal_stdlib>
using namespace metal;

struct alignas(16) GrayscaleParams {
    uint strategy;        // Conversion strategy (0-6)
    float blackThreshold; // Black threshold for contrast adjustment
    float whiteThreshold; // White threshold for contrast adjustment
};

// Grayscale conversion strategies
constant uint STRATEGY_WEIGHTED = 0;      // 0.299*R + 0.587*G + 0.114*B
constant uint STRATEGY_AVERAGE = 1;       // (R + G + B) / 3
constant uint STRATEGY_RED_CHANNEL = 2;   // Use red channel only
constant uint STRATEGY_GREEN_CHANNEL = 3; // Use green channel only
constant uint STRATEGY_BLUE_CHANNEL = 4;  // Use blue channel only
constant uint STRATEGY_MAX_CHANNEL = 5;   // Use brightest channel
constant uint STRATEGY_MIN_CHANNEL = 6;   // Use darkest channel

float adjustLevels(float black, float white, float value) {
    // Apply black threshold
    if (value < black) {
        return 0.0;
    }
    
    // Apply white threshold (clamp)
    float clampedValue = min(value, white);
    
    // Remap [black, white] to [0.0, 1.0]
    return (clampedValue - black) / (white - black);
}

float convertToGrayscale(float4 rgba, uint strategy) {
    float r = rgba.r;
    float g = rgba.g;
    float b = rgba.b;
    
    switch (strategy) {
        case STRATEGY_WEIGHTED:
            return 0.299 * r + 0.587 * g + 0.114 * b;
        case STRATEGY_AVERAGE:
            return (r + g + b) / 3.0;
        case STRATEGY_RED_CHANNEL:
            return r;
        case STRATEGY_GREEN_CHANNEL:
            return g;
        case STRATEGY_BLUE_CHANNEL:
            return b;
        case STRATEGY_MAX_CHANNEL:
            return max(r, max(g, b));
        case STRATEGY_MIN_CHANNEL:
            return min(r, min(g, b));
        default:
            return (r + g + b) / 3.0; // Default to average
    }
}

kernel void grayscale(
    texture2d<uint, access::read> inputTexture [[texture(0)]],
    texture2d<uint, access::write> outputTexture [[texture(1)]],
    constant GrayscaleParams& params [[buffer(0)]],
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
    
    // Apply level adjustment (black and white thresholds)
    float adjustedValue = adjustLevels(params.blackThreshold, params.whiteThreshold, grayscaleValue);
    
    // Convert back to 0-255 range
    uint grayscaleUint = uint(adjustedValue * 255.0);
    
    // Output as grayscale RGBA (same value for R, G, B, preserve alpha)
    outputTexture.write(uint4(grayscaleUint, grayscaleUint, grayscaleUint, inputColor.a), gid);
} 