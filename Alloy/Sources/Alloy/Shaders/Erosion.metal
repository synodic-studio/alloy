#include <metal_stdlib>
using namespace metal;

struct alignas(16) ErosionParams {
    uint iterations;    // Number of erosion iterations to perform
    uint connectivity;  // 0 = 4-connection, 1 = 8-connection
};

// Connectivity constants
constant uint CONNECTIVITY_4 = 0;
constant uint CONNECTIVITY_8 = 1;

// Check if a pixel should be eroded based on connectivity
bool shouldErode(texture2d<uint, access::read> texture, uint2 coord, uint connectivity) {
    uint width = texture.get_width();
    uint height = texture.get_height();
    
    // Read current pixel value (using red channel for grayscale)
    uint currentValue = texture.read(coord).r;
    
    // If already black, keep it black
    if (currentValue == 0) {
        return true;
    }
    
    // Check neighbors based on connectivity type
    if (connectivity == CONNECTIVITY_4) {
        // 4-connected neighbors (up, down, left, right)
        
        // Up
        if (coord.y > 0) {
            uint upValue = texture.read(uint2(coord.x, coord.y - 1)).r;
            if (upValue == 0) return true;
        }
        
        // Down  
        if (coord.y < height - 1) {
            uint downValue = texture.read(uint2(coord.x, coord.y + 1)).r;
            if (downValue == 0) return true;
        }
        
        // Left
        if (coord.x > 0) {
            uint leftValue = texture.read(uint2(coord.x - 1, coord.y)).r;
            if (leftValue == 0) return true;
        }
        
        // Right
        if (coord.x < width - 1) {
            uint rightValue = texture.read(uint2(coord.x + 1, coord.y)).r;
            if (rightValue == 0) return true;
        }
    } else {
        // 8-connected neighbors (includes diagonals)
        
        for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
                if (dx == 0 && dy == 0) continue; // Skip center pixel
                
                int2 neighborPos = int2(coord) + int2(dx, dy);
                
                // Bounds check
                if (neighborPos.x >= 0 && neighborPos.x < int(width) &&
                    neighborPos.y >= 0 && neighborPos.y < int(height)) {
                    
                    uint2 neighborCoord = uint2(neighborPos);
                    uint neighborValue = texture.read(neighborCoord).r;
                    
                    if (neighborValue == 0) {
                        return true;
                    }
                }
            }
        }
    }
    
    return false;
}

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
    uint currentValue = inputColor.r;
    
    // If already black, output black
    if (currentValue == 0) {
        outputTexture.write(uint4(0, 0, 0, inputColor.a), gid);
        return;
    }
    
    // For multiple iterations, we check if any pixel within the erosion distance is black
    // The erosion distance increases with the number of iterations
    bool shouldBeEroded = false;
    uint erosionDistance = params.iterations;
    
    if (params.connectivity == CONNECTIVITY_4) {
        // 4-connected: use Manhattan distance
        for (uint dy = 0; dy <= erosionDistance && !shouldBeEroded; dy++) {
            for (uint dx = 0; dx <= erosionDistance && !shouldBeEroded; dx++) {
                // Only check 4-connected path distances (Manhattan distance)
                if (dx + dy > erosionDistance) continue;
                if (dx == 0 && dy == 0) continue; // Skip center pixel
                
                // Check all four quadrants
                int2 offsets[4] = {
                    int2(int(dx), int(dy)),
                    int2(-int(dx), int(dy)),
                    int2(int(dx), -int(dy)),
                    int2(-int(dx), -int(dy))
                };
                
                for (int i = 0; i < 4; i++) {
                    int2 checkPos = int2(gid) + offsets[i];
                    
                    // Bounds check
                    if (checkPos.x >= 0 && checkPos.x < int(inputTexture.get_width()) &&
                        checkPos.y >= 0 && checkPos.y < int(inputTexture.get_height())) {
                        
                        uint2 checkCoord = uint2(checkPos);
                        uint checkValue = inputTexture.read(checkCoord).r;
                        
                        if (checkValue == 0) {
                            shouldBeEroded = true;
                            break;
                        }
                    }
                }
            }
        }
    } else {
        // 8-connected: use Chebyshev distance (max of dx, dy)
        for (int dy = -int(erosionDistance); dy <= int(erosionDistance) && !shouldBeEroded; dy++) {
            for (int dx = -int(erosionDistance); dx <= int(erosionDistance) && !shouldBeEroded; dx++) {
                if (dx == 0 && dy == 0) continue; // Skip center pixel
                
                // Chebyshev distance check
                if (max(abs(dx), abs(dy)) > int(erosionDistance)) continue;
                
                int2 checkPos = int2(gid) + int2(dx, dy);
                
                // Bounds check
                if (checkPos.x >= 0 && checkPos.x < int(inputTexture.get_width()) &&
                    checkPos.y >= 0 && checkPos.y < int(inputTexture.get_height())) {
                    
                    uint2 checkCoord = uint2(checkPos);
                    uint checkValue = inputTexture.read(checkCoord).r;
                    
                    if (checkValue == 0) {
                        shouldBeEroded = true;
                        break;
                    }
                }
            }
        }
    }
    
    if (shouldBeEroded) {
        outputTexture.write(uint4(0, 0, 0, inputColor.a), gid);
    } else {
        outputTexture.write(inputColor, gid);
    }
} 