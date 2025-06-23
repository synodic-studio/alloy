#include <metal_stdlib>
using namespace metal;

struct alignas(16) PeakDetectionParams {
    uint neighborhoodSize;  // 8 or 16 neighbors
    float minDistance;      // Minimum distance between peaks
    uint maxPeaks;          // Maximum number of peaks to detect
    float padding;          // Padding for 16-byte alignment
};

struct DetectedPeakData {
    float x;
    float y;
    float value;
};

kernel void peakDetection(
    texture2d<uint, access::read> inputTexture [[texture(0)]],
    texture2d<uint, access::write> outputTexture [[texture(1)]],
    device DetectedPeakData* peakBuffer [[buffer(1)]],
    device atomic_uint* peakCount [[buffer(2)]],
    constant PeakDetectionParams& params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    // Early exit if we're outside the bounds
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
        return;
    }
    
    // Read center pixel and convert to grayscale intensity
    uint4 centerColor = inputTexture.read(gid);
    float centerIntensity = (float(centerColor.r) + float(centerColor.g) + float(centerColor.b)) / (3.0 * 255.0);
    
    // Determine neighborhood size
    int neighborhoodRadius = (params.neighborhoodSize == 8) ? 1 : 2;
    
    bool isPeak = true;
    float maxNeighborValue = 0.0;
    int validNeighbors = 0;
    
    // Check all neighbors in the specified neighborhood
    for (int dy = -neighborhoodRadius; dy <= neighborhoodRadius; dy++) {
        for (int dx = -neighborhoodRadius; dx <= neighborhoodRadius; dx++) {
            // Skip center pixel
            if (dx == 0 && dy == 0) continue;
            
            int2 neighborPos = int2(gid) + int2(dx, dy);
            
            // Check bounds
            if (neighborPos.x >= 0 && neighborPos.x < int(inputTexture.get_width()) &&
                neighborPos.y >= 0 && neighborPos.y < int(inputTexture.get_height())) {
                
                uint4 neighborColor = inputTexture.read(uint2(neighborPos));
                float neighborIntensity = (float(neighborColor.r) + float(neighborColor.g) + float(neighborColor.b)) / (3.0 * 255.0);
                
                maxNeighborValue = max(maxNeighborValue, neighborIntensity);
                validNeighbors++;
                
                // If any neighbor is greater than or equal to center, it's not a peak
                if (neighborIntensity >= centerIntensity) {
                    isPeak = false;
                }
            }
        }
    }
    
    // Output visualization - highlight peaks in red
    uint4 outputColor = centerColor;
    if (isPeak && validNeighbors > 0) {
        // Try to add this peak to the buffer
        uint currentCount = atomic_fetch_add_explicit(peakCount, 1, memory_order_relaxed);
        
        if (currentCount < params.maxPeaks) {
            // Store peak data
            peakBuffer[currentCount].x = float(gid.x);
            peakBuffer[currentCount].y = float(gid.y);
            peakBuffer[currentCount].value = centerIntensity;
        }
        
        // Highlight peak in red for visualization
        outputColor = uint4(255, 0, 0, centerColor.a);
    }
    
    outputTexture.write(outputColor, gid);
} 