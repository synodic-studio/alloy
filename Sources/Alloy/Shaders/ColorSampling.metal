#include <metal_stdlib>
using namespace metal;

struct alignas(16) ColorSamplingParams {
    uint sampleCount;      // Number of positions to sample
    float radius;          // Sampling radius (3.0)
    uint padding1;         // 16-byte alignment
    uint padding2;
};

struct SamplePosition {
    float x;
    float y;
};

struct ColorResult {
    float r;  // Normalized 0.0-1.0
    float g;
    float b;
    float a;
};

kernel void sampleColors(
    texture2d<uint, access::read> inputTexture [[texture(0)]],
    device const SamplePosition* positions [[buffer(1)]],
    device ColorResult* outputColors [[buffer(2)]],
    constant ColorSamplingParams& params [[buffer(0)]],
    uint id [[thread_position_in_grid]]
) {
    // Early exit for out-of-bounds threads
    if (id >= params.sampleCount) {
        return;
    }

    // Get sampling position
    float2 center = float2(positions[id].x, positions[id].y);
    float radius = params.radius;

    // Circular averaging (same algorithm as CPU version)
    float sumR = 0.0, sumG = 0.0, sumB = 0.0, sumA = 0.0;
    uint pixelCount = 0;

    int radiusInt = int(radius);
    int minX = max(0, int(center.x) - radiusInt);
    int maxX = min(int(inputTexture.get_width()) - 1, int(center.x) + radiusInt);
    int minY = max(0, int(center.y) - radiusInt);
    int maxY = min(int(inputTexture.get_height()) - 1, int(center.y) + radiusInt);

    // Iterate circular region
    for (int y = minY; y <= maxY; y++) {
        for (int x = minX; x <= maxX; x++) {
            float dx = float(x) - center.x;
            float dy = float(y) - center.y;
            float distance = sqrt(dx*dx + dy*dy);

            if (distance <= radius) {
                uint2 coord = uint2(x, y);
                uint4 pixel = inputTexture.read(coord);

                sumR += float(pixel.r);
                sumG += float(pixel.g);
                sumB += float(pixel.b);
                sumA += float(pixel.a);
                pixelCount++;
            }
        }
    }

    // Average and normalize to 0.0-1.0 range
    if (pixelCount > 0) {
        outputColors[id].r = (sumR / float(pixelCount)) / 255.0;
        outputColors[id].g = (sumG / float(pixelCount)) / 255.0;
        outputColors[id].b = (sumB / float(pixelCount)) / 255.0;
        outputColors[id].a = (sumA / float(pixelCount)) / 255.0;
    } else {
        // Gray fallback for invalid positions
        outputColors[id] = ColorResult{0.5, 0.5, 0.5, 1.0};
    }
}
