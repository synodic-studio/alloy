#include <metal_stdlib>
using namespace metal;

struct alignas(16) NoiseParams {
    float magnitude;     // Noise magnitude (0.0-1.0)
    uint seed;           // Random seed
    uint ignoreBlack;    // Whether to ignore black pixels (0 = false, 1 = true)
    uint ignoreWhite;    // Whether to ignore white pixels (0 = false, 1 = true)
};

// Simple pseudo-random number generator
uint rng_state(uint2 pixel, uint seed) {
    uint state = pixel.x + pixel.y * 1973u + seed;
    state = (state ^ 61u) ^ (state >> 16u);
    state *= 9u;
    state = state ^ (state >> 4u);
    state *= 0x27d4eb2du;
    state = state ^ (state >> 15u);
    return state;
}

float random_float(uint state) {
    return float(state) / float(0xFFFFFFFFu);
}

kernel void noise(
    texture2d<uint, access::read> inputTexture [[texture(0)]],
    texture2d<uint, access::write> outputTexture [[texture(1)]],
    constant NoiseParams& params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    // Early exit if we're outside the output bounds
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    
    // Read input pixel
    uint4 inputColor = inputTexture.read(gid);
    
    // Check if we should ignore this pixel based on its color
    bool isPureBlack = (inputColor.r == 0 && inputColor.g == 0 && inputColor.b == 0);
    bool isPureWhite = (inputColor.r == 255 && inputColor.g == 255 && inputColor.b == 255);
    
    bool shouldIgnore = (params.ignoreBlack && isPureBlack) || (params.ignoreWhite && isPureWhite);
    
    if (shouldIgnore) {
        // Skip noise and output the original pixel unchanged
        outputTexture.write(inputColor, gid);
        return;
    }
    
    // Check if this is grayscale data (R=G=B)
    bool isGrayscale = (inputColor.r == inputColor.g && inputColor.g == inputColor.b);
    
    // Generate noise
    uint state = rng_state(gid, params.seed);
    float noiseValue = (random_float(state) - 0.5) * 2.0;  // Range [-1, 1]
    
    // Scale noise by magnitude (magnitude is 0.0-1.0, so scale to 0-255 range)
    float noiseScale = params.magnitude * 255.0;
    int noiseAmount = int(noiseValue * noiseScale);
    
    uint4 outputColor;
    
    if (isGrayscale) {
        // For grayscale, apply same noise to all RGB channels
        int noisyValue = int(inputColor.r) + noiseAmount;
        uint clampedValue = uint(clamp(noisyValue, 0, 255));
        outputColor = uint4(clampedValue, clampedValue, clampedValue, inputColor.a);
    } else {
        // For color images, apply independent noise to each channel
        state = rng_state(gid, params.seed);
        float noiseR = (random_float(state) - 0.5) * 2.0;
        state = rng_state(gid + uint2(1, 0), params.seed);
        float noiseG = (random_float(state) - 0.5) * 2.0;
        state = rng_state(gid + uint2(0, 1), params.seed);
        float noiseB = (random_float(state) - 0.5) * 2.0;
        
        // Apply noise to each channel and clamp to valid range
        int4 noisyColor = int4(inputColor) + int4(
            int(noiseR * noiseScale),
            int(noiseG * noiseScale),
            int(noiseB * noiseScale),
            0  // Don't add noise to alpha channel
        );
        
        // Clamp to valid 0-255 range
        outputColor = uint4(
            clamp(noisyColor.r, 0, 255),
            clamp(noisyColor.g, 0, 255),
            clamp(noisyColor.b, 0, 255),
            inputColor.a  // Preserve original alpha
        );
    }
    
    outputTexture.write(outputColor, gid);
} 