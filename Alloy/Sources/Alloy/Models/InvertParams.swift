import Metal

/// Parameters for the image invert shader
struct InvertParams: MetalShaderParameters {
    // No specific parameters needed for basic invert, but we need the struct for consistency
    // Adding a dummy parameter to maintain 16-byte alignment requirement
    private let dummy: UInt32 = 0         // 4 bytes
    private let padding1: UInt32 = 0      // 4 bytes
    private let padding2: UInt32 = 0      // 4 bytes  
    private let padding3: UInt32 = 0      // 4 bytes (total: 16 bytes)
    
    var bufferIndex: Int { 0 }
    
    init() {
        // Empty initializer since no parameters are needed
    }
} 