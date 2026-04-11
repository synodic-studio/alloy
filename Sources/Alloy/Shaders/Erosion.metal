#include <metal_stdlib>
using namespace metal;

struct alignas(16) ErosionParams {
    uint iterations;    // Number of erosion iterations to perform
    uint connectivity;  // 0 = 4-connection, 1 = 8-connection
};

// Connectivity constants
constant uint CONNECTIVITY_4 = 0;
constant uint CONNECTIVITY_8 = 1;

kernel void erosion(
    texture2d<uint, access::read> inputTexture [[texture(0)]],
    texture2d<uint, access::write> outputTexture [[texture(1)]],
    constant ErosionParams& params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    // Early exit if we're outside the output bounds
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    
    uint4 inputColor = inputTexture.read(gid);
    
    // For multiple iterations, we need to check if any pixel within the specified distance has a black pixel
    // that would "reach" this pixel through the erosion process
    bool shouldErode = false;
    
    // Check all pixels within the erosion distance
    for (uint iteration = 1; iteration <= params.iterations && !shouldErode; iteration++) {
        if (params.connectivity == CONNECTIVITY_4) {
            // 4-connected erosion: check Manhattan distance
            for (int dy = -int(iteration); dy <= int(iteration); dy++) {
                for (int dx = -int(iteration); dx <= int(iteration); dx++) {
                    // Skip pixels outside Manhattan distance
                    if (abs(dx) + abs(dy) != int(iteration)) continue;
                    
                    int2 checkPos = int2(gid) + int2(dx, dy);
                    
                    if (checkPos.x >= 0 && checkPos.x < int(inputTexture.get_width()) &&
                        checkPos.y >= 0 && checkPos.y < int(inputTexture.get_height())) {
                        
                        uint checkValue = inputTexture.read(uint2(checkPos)).r;
                        if (checkValue == 0) {
                            shouldErode = true;
                            break;
                        }
                    }
                }
                if (shouldErode) break;
            }
        } else {
            // 8-connected erosion: check Chebyshev distance
            for (int dy = -int(iteration); dy <= int(iteration); dy++) {
                for (int dx = -int(iteration); dx <= int(iteration); dx++) {
                    // Skip pixels outside Chebyshev distance
                    if (max(abs(dx), abs(dy)) != int(iteration)) continue;
                    
                    int2 checkPos = int2(gid) + int2(dx, dy);
                    
                    if (checkPos.x >= 0 && checkPos.x < int(inputTexture.get_width()) &&
                        checkPos.y >= 0 && checkPos.y < int(inputTexture.get_height())) {
                        
                        uint checkValue = inputTexture.read(uint2(checkPos)).r;
                        if (checkValue == 0) {
                            shouldErode = true;
                            break;
                        }
                    }
                }
                if (shouldErode) break;
            }
        }
    }
    
    if (shouldErode) {
        // Erode to black, preserve alpha
        outputTexture.write(uint4(0, 0, 0, inputColor.a), gid);
    } else {
        // Keep original color
        outputTexture.write(inputColor, gid);
    }
} 