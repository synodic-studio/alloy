import Metal

/// Parameters for the debayer shader
struct DebayerParams: MetalShaderParameters {
    let bitDepth: UInt32               // 4 bytes
    
    // Padding to match Metal's alignas(16) requirement (total must be 16 bytes)
    private let padding1: UInt32 = 0   // 4 bytes padding
    private let padding2: UInt32 = 0   // 4 bytes padding  
    private let padding3: UInt32 = 0   // 4 bytes padding (total: 4 + 12 = 16 bytes)
    
    var bufferIndex: Int { 0 }
} 