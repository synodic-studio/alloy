#include <metal_stdlib>
using namespace metal;

struct alignas(16) DonutParams {
    uint2 center;      // Center of the donut
    uint innerRadius;  // Inner radius of the donut
};

kernel void donutMask(
    texture2d<uint, access::read> inputTexture [[texture(0)]],
    texture2d<uint, access::write> outputTexture [[texture(1)]],
    constant DonutParams& params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    // Early exit if we're outside the output bounds
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    
    // Calculate distance from center
    float dx = float(gid.x) - float(params.center.x);
    float dy = float(gid.y) - float(params.center.y);
    float distanceSquared = dx * dx + dy * dy;
    
    // Read input pixel
    uint4 inputColor = inputTexture.read(gid);
    
    // Calculate outer radius (half the image width since it's square)
    float outerRadius = float(outputTexture.get_width()) / 2.0;
    float outerRadiusSquared = outerRadius * outerRadius;
    float innerRadiusSquared = float(params.innerRadius) * float(params.innerRadius);
    
    // Keep original color only for pixels between inner and outer radius
    if (distanceSquared <= outerRadiusSquared && distanceSquared >= innerRadiusSquared) {
        // Between inner and outer radius - keep original color with full alpha
        outputTexture.write(uint4(inputColor[0], inputColor[1], inputColor[2], 255), gid);
    } else {
        // Inside inner circle or outside outer circle - make transparent
        outputTexture.write(uint4(inputColor[0], inputColor[1], inputColor[2], 0), gid);
    }
} 