import Metal

/// Parameters for the blur shader
struct BlurParams: MetalShaderParameters {
    let radius: Float // Blur radius in pixels - 4 bytes
    private let _padding: SIMD3<UInt32> = SIMD3<UInt32>(0, 0, 0) // Padding to align to 16 bytes - 12 bytes

    var bufferIndex: Int { 0 }

    init(radius: Double) {
        self.radius = Float(radius)
    }
}
