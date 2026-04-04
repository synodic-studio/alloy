//
//  Debayer.metal
//  GravityWell
//
//  Created by Bryan Costanza on 3/12/25.
//

#include <metal_stdlib>
using namespace metal;

// Structure to hold our parameters
struct alignas(16) DebayerParams {
    uint bitDepth;
};

kernel void debayerKernelRGGB(
    texture2d<uint, access::read> rawTexture [[texture(0)]],
    texture2d<uint, access::write> outputTexture [[texture(1)]],
    constant DebayerParams& params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    // Output dimensions are half of input
    uint outputWidth = outputTexture.get_width();
    uint outputHeight = outputTexture.get_height();
    
    // Check boundaries for the output image
    if (gid.x >= outputWidth || gid.y >= outputHeight) {
        return;
    }
    
    // Calculate the corresponding top-left corner of the 2x2 block in the input image
    uint2 blockStart = gid * 2;
    
    // Initialize RGB values
    uint r = 0, g = 0, b = 0;
    
    // For a 2x2 RGGB Bayer pattern:
    // R G
    // G B
    
    // Get red from top-left pixel (0,0)
    r = rawTexture.read(blockStart).r;
    
    // Get green from top-right pixel (using G1)
    uint2 gPos = uint2(blockStart.x + 1, blockStart.y);
    if (gPos.x < rawTexture.get_width()) {
        g = rawTexture.read(gPos).r;
    }
    
    // Get blue from bottom-right pixel (1,1)
    uint2 bPos = blockStart + uint2(1, 1);
    if (bPos.x < rawTexture.get_width() && bPos.y < rawTexture.get_height()) {
        b = rawTexture.read(bPos).r;
    }
    
    // If we're dealing with 16-bit input, scale down to 8-bit
    if (params.bitDepth == 16) {
        r >>= 8;
        g >>= 8;
        b >>= 8;
    }
    
    // Write RGBA values (using full 255 for alpha)
    outputTexture.write(uint4(r, g, b, 255), gid);
}
