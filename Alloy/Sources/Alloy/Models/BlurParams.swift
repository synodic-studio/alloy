import Metal

/// Parameters for the blur shader
struct BlurParams: MetalShaderParameters {
    let radius: Float              // Blur radius in pixels - 4 bytes
    
    // Padding to match Metal's alignas(16) requirement (16 bytes total needed)
    private let padding1: UInt32 = 0    // 4 bytes padding
    private let padding2: UInt32 = 0    // 4 bytes padding  
    private let padding3: UInt32 = 0    // 4 bytes padding (total: 4 + 12 = 16 bytes)
    
    var bufferIndex: Int { 0 }
    
    init(radius: Double) {
        self.radius = Float(radius)
    }
} 