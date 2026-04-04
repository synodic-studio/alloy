import Metal

/// Parameters for the debayer shader
struct DebayerParams: MetalShaderParameters {
    let bitDepth: UInt32 // 4 bytes
    private let _padding: SIMD3<UInt32> = SIMD3<UInt32>(0, 0, 0) // Padding to align to 16 bytes - 12 bytes

    var bufferIndex: Int { 0 }
}
