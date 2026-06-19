import Metal

/// Parameters for the binary threshold shader
struct BinaryThresholdParams: MetalShaderParameters {
    let threshold: Float   // Threshold value (0.0-1.0) - 4 bytes
    let strategy: UInt32   // Grayscale conversion strategy - 4 bytes
    private let _padding: SIMD2<Float> = SIMD2<Float>(0, 0) // Padding to align to 16 bytes - 8 bytes

    var bufferIndex: Int { 0 }

    init(threshold: Double, strategy: GrayscaleConversionStrategy) {
        self.threshold = Float(threshold)
        self.strategy = strategy.metalValue
    }
}
