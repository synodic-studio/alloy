import Metal

/// Parameters for the image invert shader
struct InvertParams: MetalShaderParameters {
    private let dummy: UInt32 = 0 // Dummy parameter to match Metal shader - 4 bytes
    private let _padding: SIMD3<UInt32> = SIMD3<UInt32>(0, 0, 0) // Padding to align to 16 bytes - 12 bytes

    var bufferIndex: Int { 0 }

    init() {
        // Empty initializer since no parameters are needed
    }
}
