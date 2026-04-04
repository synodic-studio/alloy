#include <metal_stdlib>
using namespace metal;

struct alignas(16) CropParams {
    uint2 center;
    uint sideLength;
};

kernel void squareCrop(
    texture2d<uint, access::read> inputTexture [[texture(0)]],
    texture2d<uint, access::write> outputTexture [[texture(1)]],
    constant CropParams& params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    // Early exit if we're outside the output bounds
    if (gid.x >= params.sideLength || gid.y >= params.sideLength) {
        return;
    }
    
    // Calculate the top-left corner of our crop region
    uint2 topLeft = params.center - uint2(params.sideLength / 2);
    
    // Calculate source coordinates
    uint2 sourceCoord = topLeft + gid;
    
    // Check if source coordinate is within input bounds
    if (sourceCoord.x >= inputTexture.get_width() || sourceCoord.y >= inputTexture.get_height()) {
        // Out of bounds - write black pixel with full alpha
        outputTexture.write(uint4(0, 0, 0, 255), gid);
        return;
    }
    
    // Read from input and write to output
    uint4 color = inputTexture.read(sourceCoord);
    outputTexture.write(color, gid);
} 