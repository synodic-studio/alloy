#include <metal_stdlib>
using namespace metal;

// Struct to match the Swift-side DetectedPeak struct
struct Peak {
    float2 position;
    float correlation;
    float radius;
};

// Kernel to find local maxima in a 2D correlation texture
kernel void findPeaks(
    texture2d<float, access::read> correlationTexture [[texture(0)]],
    device Peak *peaks [[buffer(0)]],
    device atomic_uint& peakCount [[buffer(1)]],
    constant float& threshold [[buffer(2)]],
    constant float& radius [[buffer(3)]],
    uint2 gid [[thread_position_in_grid]]
) {
    // Ensure we are within the texture bounds
    if (gid.x >= correlationTexture.get_width() || gid.y >= correlationTexture.get_height()) {
        return;
    }

    float centerValue = correlationTexture.read(gid).r;

    // 1. Check if the center value is above the threshold
    if (centerValue < threshold) {
        return;
    }

    // 2. Check if the center value is a local maximum in a 5x5 neighborhood
    // To avoid edge issues, we'll check bounds before reading.
    for (int y = -2; y <= 2; ++y) {
        for (int x = -2; x <= 2; ++x) {
            if (x == 0 && y == 0) continue;

            int2 neighborCoord = int2(gid) + int2(x, y);

            // Clamp coordinates to be within texture bounds
            neighborCoord.x = clamp(neighborCoord.x, 0, (int)correlationTexture.get_width() - 1);
            neighborCoord.y = clamp(neighborCoord.y, 0, (int)correlationTexture.get_height() - 1);

            if (correlationTexture.read(uint2(neighborCoord)).r > centerValue) {
                // Not a local maximum
                return;
            }
        }
    }

    // 3. If it is a local maximum, atomically add it to the peaks buffer
    uint index = atomic_fetch_add_explicit(&peakCount, 1, memory_order_relaxed);
    
    // Check if we are out of buffer space (optional safety)
    if (index >= 1000) { // Hard limit to prevent buffer overflow
        return;
    }
    
    peaks[index].position = float2(gid);
    peaks[index].correlation = centerValue;
    peaks[index].radius = radius;
} 