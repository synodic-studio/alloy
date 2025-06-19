import Metal

/// Parameters for the donut mask shader
struct DonutParams: MetalShaderParameters {
    let center: SIMD2<UInt32>      // Center of the donut (x, y) - 8 bytes
    let innerRadius: UInt32        // Inner radius of the donut - 4 bytes
    
    // Padding to match Metal's alignas(16) requirement (16 bytes total needed)
    private let padding: UInt32 = 0    // 4 bytes padding (total: 12 + 4 = 16 bytes)
    
    var bufferIndex: Int { 0 }
} 