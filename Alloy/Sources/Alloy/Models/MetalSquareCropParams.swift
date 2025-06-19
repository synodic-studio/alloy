import Metal

/// Metal shader parameter struct for square crop operations
struct MetalSquareCropParams: MetalShaderParameters {
    let center: SIMD2<UInt32>      // Center point of the crop (x, y) - 8 bytes
    let sideLength: UInt32         // Side length of the square crop - 4 bytes
    
    // Padding to match Metal's alignas(16) requirement (16 bytes total needed)
    private let padding: UInt32 = 0    // 4 bytes padding (total: 12 + 4 = 16 bytes)
    
    var bufferIndex: Int { 0 }
} 