import Metal

/// Parameters for the noise shader
struct NoiseParams: MetalShaderParameters {
    let magnitude: Float           // Noise magnitude (0.0-1.0) - 4 bytes
    let seed: UInt32               // Random seed for reproducible results - 4 bytes
    
    // Padding to match Metal's alignas(16) requirement (16 bytes total needed)
    private let padding1: UInt32 = 0    // 4 bytes padding
    private let padding2: UInt32 = 0    // 4 bytes padding (total: 8 + 8 = 16 bytes)
    
    var bufferIndex: Int { 0 }
    
    init(magnitude: Double, seed: UInt32 = UInt32.random(in: 0...UInt32.max)) {
        self.magnitude = Float(magnitude)
        self.seed = seed
    }
} 