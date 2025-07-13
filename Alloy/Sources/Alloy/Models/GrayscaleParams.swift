import Metal

/// Parameters for the grayscale conversion shader
struct GrayscaleParams: MetalShaderParameters {
    let strategy: UInt32           // Grayscale conversion strategy (0-6) - 4 bytes
    let blackThreshold: Float      // Black threshold for contrast adjustment - 4 bytes
    let whiteThreshold: Float      // White threshold for contrast adjustment - 4 bytes
    
    // Padding to match Metal's alignas(16) requirement (16 bytes total needed)
    private let padding: UInt32 = 0    // 4 bytes padding (total: 12 + 4 = 16 bytes)
    
    var bufferIndex: Int { 0 }
    
    init(strategy: GrayscaleConversionStrategy, blackThreshold: Double = 0.0, whiteThreshold: Double = 1.0) {
        self.strategy = strategy.metalValue
        self.blackThreshold = Float(blackThreshold)
        self.whiteThreshold = Float(whiteThreshold)
    }
}

extension GrayscaleConversionStrategy {
    /// Metal shader strategy constants
    public var metalValue: UInt32 {
        return UInt32(self.rawValue)
    }
} 