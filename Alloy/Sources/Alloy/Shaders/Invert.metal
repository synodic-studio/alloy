#include <metal_stdlib>
using namespace metal;

struct alignas(16) InvertParams {
    uint dummy;  // No specific parameters needed for basic invert
};

kernel void invert(
    texture2d<uint, access::read> inputTexture [[texture(0)]],
    texture2d<uint, access::write> outputTexture [[texture(1)]],
    constant InvertParams& params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    // Early exit if we're outside the output bounds
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    
    // Read input pixel
    uint4 inputColor = inputTexture.read(gid);
    
    // Invert the RGB channels (subtract from 255), preserve alpha
    uint4 invertedColor = uint4(
        255 - inputColor.r,
        255 - inputColor.g,
        255 - inputColor.b,
        inputColor.a
    );
    
    // Write inverted color to output
    outputTexture.write(invertedColor, gid);
} 