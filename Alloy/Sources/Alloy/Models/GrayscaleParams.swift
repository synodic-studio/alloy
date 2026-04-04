import Metal

/// Parameters for the grayscale conversion shader
struct GrayscaleParams: MetalShaderParameters {
    let strategy: UInt32 // Grayscale conversion strategy (0-6) - 4 bytes
    let blackThreshold: Float // Black threshold for contrast adjustment - 4 bytes
    let whiteThreshold: Float // White threshold for contrast adjustment - 4 bytes
    private let _padding: UInt32 = 0 // Padding to align to 16 bytes - 4 bytes

    var bufferIndex: Int { 0 }

    init(strategy: GrayscaleConversionStrategy, blackThreshold: Double = 0.0, whiteThreshold: Double = 1.0) {
        self.strategy = strategy.metalValue
        self.blackThreshold = Float(blackThreshold)
        self.whiteThreshold = Float(whiteThreshold)
    }
}

public extension GrayscaleConversionStrategy {
    /// Metal shader strategy constants
    var metalValue: UInt32 {
        UInt32(self.rawValue)
    }
}
