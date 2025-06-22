#include <metal_stdlib>
using namespace metal;

struct alignas(16) BlurParams {
    float radius;        // Blur radius in pixels
};

kernel void blur(
    texture2d<uint, access::read> inputTexture [[texture(0)]],
    texture2d<uint, access::write> outputTexture [[texture(1)]],
    constant BlurParams& params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    // Early exit if we're outside the output bounds
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    
    float4 accumulatedColor = float4(0.0);
    float totalWeight = 0.0;
    
    int radiusInt = int(ceil(params.radius));
    
    // Iterate through neighboring pixels within the radius
    for (int dy = -radiusInt; dy <= radiusInt; dy++) {
        for (int dx = -radiusInt; dx <= radiusInt; dx++) {
            float distance = sqrt(float(dx * dx + dy * dy));
            
            // Only process pixels within the specified radius
            if (distance <= params.radius) {
                int2 samplePos = int2(gid) + int2(dx, dy);
                
                // Check bounds
                if (samplePos.x >= 0 && samplePos.x < int(inputTexture.get_width()) &&
                    samplePos.y >= 0 && samplePos.y < int(inputTexture.get_height())) {
                    
                    // Calculate weight using 1/r² (with special case for center pixel)
                    float weight;
                    if (distance < 0.5) {
                        // Center pixel gets maximum weight
                        weight = 1.0;
                    } else {
                        // 1/r² weighting for other pixels
                        weight = 1.0 / (distance * distance);
                    }
                    
                    // Read pixel and accumulate
                    uint4 sampleColor = inputTexture.read(uint2(samplePos));
                    float4 normalizedColor = float4(sampleColor) / 255.0;
                    
                    accumulatedColor += normalizedColor * weight;
                    totalWeight += weight;
                }
            }
        }
    }
    
    // Normalize and convert back to 0-255 range
    float4 finalColor = accumulatedColor / totalWeight;
    uint4 outputColor = uint4(finalColor * 255.0);
    
    outputTexture.write(outputColor, gid);
} 