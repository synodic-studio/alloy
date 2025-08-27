import Metal

/// Parameters for the noise shader
struct NoiseParams: MetalShaderParameters {
    let magnitude: Float // Noise magnitude (0.0-1.0) - 4 bytes
    let seed: UInt32 // Random seed for reproducible results - 4 bytes
    let ignoreBlack: UInt32 // Whether to ignore black pixels (0 = false, 1 = true) - 4 bytes
    let ignoreWhite: UInt32 // Whether to ignore white pixels (0 = false, 1 = true) - 4 bytes

    // Total: 16 bytes (perfectly aligned for Metal)

    var bufferIndex: Int { 0 }

    init(
        magnitude: Double,
        seed: UInt32 = UInt32.random(in: 0 ... UInt32.max),
        ignoreBlack: Bool = false,
        ignoreWhite: Bool = false
    ) {
        self.magnitude = Float(magnitude)
        self.seed = seed
        self.ignoreBlack = ignoreBlack ? 1 : 0
        self.ignoreWhite = ignoreWhite ? 1 : 0
    }
}
