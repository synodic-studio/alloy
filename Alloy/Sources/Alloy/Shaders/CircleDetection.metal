#include <metal_stdlib>
using namespace metal;

struct alignas(16) SobelCircleDetectionParams {
    uint minRadius;    // Minimum circle radius
    uint maxRadius;    // Maximum circle radius  
    float threshold;   // Edge detection threshold
    uint maxCircles;   // Maximum number of circles to detect
};

struct DetectedCircleData {
    float x;
    float y;
    float radius;
    float confidence;
};

// Simple edge detection using Sobel operator
float detectEdge(texture2d<uint, access::read> texture, uint2 coord) {
    if (coord.x == 0 || coord.y == 0 || 
        coord.x >= texture.get_width() - 1 || coord.y >= texture.get_height() - 1) {
        return 0.0;
    }
    
    // Sobel X kernel
    float gx = 
        -1.0 * float(texture.read(uint2(coord.x - 1, coord.y - 1)).r) +
        -2.0 * float(texture.read(uint2(coord.x - 1, coord.y)).r) +
        -1.0 * float(texture.read(uint2(coord.x - 1, coord.y + 1)).r) +
         1.0 * float(texture.read(uint2(coord.x + 1, coord.y - 1)).r) +
         2.0 * float(texture.read(uint2(coord.x + 1, coord.y)).r) +
         1.0 * float(texture.read(uint2(coord.x + 1, coord.y + 1)).r);
    
    // Sobel Y kernel
    float gy = 
        -1.0 * float(texture.read(uint2(coord.x - 1, coord.y - 1)).r) +
        -2.0 * float(texture.read(uint2(coord.x, coord.y - 1)).r) +
        -1.0 * float(texture.read(uint2(coord.x + 1, coord.y - 1)).r) +
         1.0 * float(texture.read(uint2(coord.x - 1, coord.y + 1)).r) +
         2.0 * float(texture.read(uint2(coord.x, coord.y + 1)).r) +
         1.0 * float(texture.read(uint2(coord.x + 1, coord.y + 1)).r);
    
    return sqrt(gx * gx + gy * gy) / 255.0;
}

// Check if a circle of given radius centered at (cx, cy) has strong edges
float evaluateCircle(texture2d<uint, access::read> texture, float cx, float cy, float radius, float threshold) {
    float score = 0.0;
    int samples = 32; // Number of points to sample around circle
    int validSamples = 0;
    
    for (int i = 0; i < samples; i++) {
        float angle = (float(i) / float(samples)) * 2.0 * M_PI_F;
        float x = cx + radius * cos(angle);
        float y = cy + radius * sin(angle);
        
        uint2 coord = uint2(uint(x + 0.5), uint(y + 0.5));
        
        if (coord.x < texture.get_width() && coord.y < texture.get_height()) {
            float edge = detectEdge(texture, coord);
            if (edge > threshold) {
                score += edge;
            }
            validSamples++;
        }
    }
    
    return validSamples > 0 ? score / float(validSamples) : 0.0;
}

kernel void circleDetection(
    texture2d<uint, access::read> inputTexture [[texture(0)]],
    texture2d<uint, access::write> outputTexture [[texture(1)]],
    device DetectedCircleData* circleBuffer [[buffer(1)]],
    device atomic_uint* circleCount [[buffer(2)]],
    constant SobelCircleDetectionParams& params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    // Early exit if we're outside the bounds
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
        return;
    }
    
    // Copy input to output (edge-detected image)
    uint4 inputColor = inputTexture.read(gid);
    float edge = detectEdge(inputTexture, gid);
    uint edgeValue = uint(edge * 255.0);
    outputTexture.write(uint4(edgeValue, edgeValue, edgeValue, inputColor.a), gid);
    
    // Skip circle detection on edge pixels to avoid redundant work
    if (gid.x % 4 != 0 || gid.y % 4 != 0) {
        return;
    }
    
    float cx = float(gid.x);
    float cy = float(gid.y);
    
    // Try different radii
    for (uint r = params.minRadius; r <= params.maxRadius; r += 2) {
        float radius = float(r);
        
        // Skip if circle would go outside image bounds
        if (cx - radius < 0 || cx + radius >= float(inputTexture.get_width()) ||
            cy - radius < 0 || cy + radius >= float(inputTexture.get_height())) {
            continue;
        }
        
        float score = evaluateCircle(inputTexture, cx, cy, radius, params.threshold);
        
        // Use a higher threshold for detection to reduce false positives
        float detectionThreshold = params.threshold * 8.0;
        
        if (score > detectionThreshold) {
            // Atomic increment to get next available slot
            uint index = atomic_fetch_add_explicit(circleCount, 1, memory_order_relaxed);
            
            if (index < params.maxCircles) {
                circleBuffer[index].x = cx;
                circleBuffer[index].y = cy;
                circleBuffer[index].radius = radius;
                circleBuffer[index].confidence = score;
            }
        }
    }
} 