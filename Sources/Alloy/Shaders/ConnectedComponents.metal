#include <metal_stdlib>
using namespace metal;

struct alignas(16) ConnectedComponentsParams {
    uint maxComponents;       // Maximum number of components to detect - 4 bytes
    uint maxPixelsPerBlob;    // Maximum pixels allowed per blob (area filter) - 4 bytes
    uint searchWindowSize;    // Search window size for flood fill - 4 bytes
    uint padding1;            // Padding for alignment - 4 bytes
};

struct ComponentData {
    float centroidX;
    float centroidY;
    uint pixelCount;
    uint padding;
};

// Helper function to check if a pixel is white (value 255)
bool isWhitePixel(texture2d<uint, access::read> inputTexture, uint2 coord) {
    if (coord.x >= inputTexture.get_width() || coord.y >= inputTexture.get_height()) {
        return false;
    }
    uint4 pixel = inputTexture.read(coord);
    // Check if any channel is white (255) - should be pure white for binary image
    return pixel.r == 255 || pixel.g == 255 || pixel.b == 255;
}

// Get 8-connected neighbors
constant uint2 neighbors[8] = {
    uint2(-1, -1), uint2(0, -1), uint2(1, -1),
    uint2(-1,  0),               uint2(1,  0),
    uint2(-1,  1), uint2(0,  1), uint2(1,  1)
};

// Main kernel for connected components analysis
kernel void connectedComponents(
    texture2d<uint, access::read> inputTexture [[texture(0)]],
    texture2d<uint, access::write> outputTexture [[texture(1)]],
    device ComponentData* components [[buffer(1)]],
    device atomic_uint* componentCount [[buffer(2)]],
    constant ConnectedComponentsParams& params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
        return;
    }
    
    // Copy input to output
    uint4 inputPixel = inputTexture.read(gid);
    outputTexture.write(inputPixel, gid);
    
    if (!isWhitePixel(inputTexture, gid)) {
        return;
    }
    
    // Simple flood-fill approach for each white pixel
    // Check if we've already processed this pixel by looking at surrounding area
    bool alreadyProcessed = false;
    for (int dy = -1; dy <= 0 && !alreadyProcessed; dy++) {
        for (int dx = -1; dx <= (dy == 0 ? -1 : 1) && !alreadyProcessed; dx++) {
            uint2 checkPos = uint2(int2(gid) + int2(dx, dy));
            if (checkPos.x < inputTexture.get_width() && checkPos.y < inputTexture.get_height()) {
                if (isWhitePixel(inputTexture, checkPos)) {
                    alreadyProcessed = true;
                }
            }
        }
    }
    
    if (alreadyProcessed) {
        return; // Another thread will handle this component
    }
    
    // Count connected component starting from this pixel
    uint pixelCount = 0;
    float sumX = 0.0;
    float sumY = 0.0;
    uint minX = gid.x;
    uint maxX = gid.x;
    uint minY = gid.y;
    uint maxY = gid.y;

    // The seed is always the topmost-then-leftmost pixel of the blob (raster
    // scan order), so nothing can lie above it - but for non-rectangular
    // shapes (a circle, e.g. a ball), rows below the seed bulge out to BOTH
    // sides of it, not just the right. Scan symmetrically in x; only y stays
    // downward-only. searchWindowSize is the reach in each direction.
    int reach = int(params.searchWindowSize);
    uint xMin = uint(max(0, int(gid.x) - reach));
    uint xMax = uint(min(int(inputTexture.get_width()), int(gid.x) + reach));
    uint yMax = uint(min(int(inputTexture.get_height()), int(gid.y) + 2 * reach));

    // Bail out once the blob is already known to exceed the area filter -
    // it will be discarded below regardless, so finishing the scan is wasted
    // work.
    bool exceededCap = false;

    for (uint y = gid.y; y < yMax && !exceededCap; y++) {
        for (uint x = xMin; x < xMax && !exceededCap; x++) {
            uint2 pos = uint2(x, y);
            if (isWhitePixel(inputTexture, pos)) {
                // Check if this pixel is connected to our starting pixel
                bool connected = false;
                if (x == gid.x && y == gid.y) {
                    connected = true;
                } else {
                    // Simple connectivity check - if adjacent to already counted pixels
                    for (int dy = -1; dy <= 1 && !connected; dy++) {
                        for (int dx = -1; dx <= 1 && !connected; dx++) {
                            if (dx == 0 && dy == 0) continue;
                            uint2 adjPos = uint2(int2(x, y) + int2(dx, dy));
                            if (adjPos.x >= xMin && adjPos.y >= gid.y &&
                                adjPos.x < x + 1 && adjPos.y < y + 1 &&
                                adjPos.x < inputTexture.get_width() && adjPos.y < inputTexture.get_height()) {
                                if (isWhitePixel(inputTexture, adjPos)) {
                                    connected = true;
                                }
                            }
                        }
                    }
                }

                if (connected) {
                    pixelCount++;
                    sumX += float(x);
                    sumY += float(y);
                    minX = min(minX, x);
                    maxX = max(maxX, x);
                    minY = min(minY, y);
                    maxY = max(maxY, y);

                    if (pixelCount > params.maxPixelsPerBlob) {
                        exceededCap = true;
                    }
                }
            }
        }
    }
    
    // Filter blobs based on total pixel count (area)
    if (pixelCount > 0 && pixelCount <= params.maxPixelsPerBlob) {
        uint componentIndex = atomic_fetch_add_explicit(componentCount, 1, memory_order_relaxed);
        
        if (componentIndex < params.maxComponents) {
            float centroidX = sumX / float(pixelCount);
            float centroidY = sumY / float(pixelCount);
            
            components[componentIndex] = ComponentData{
                centroidX,
                centroidY,
                pixelCount,
                0 // padding
            };
        }
    }
} 