import Metal

/// Metal shader parameter struct for square crop operations
struct MetalSquareCropParams: MetalShaderParameters {
    let center: SIMD2<UInt32> // Center point of the crop (x, y) - 8 bytes
    let sideLength: UInt32 // Side length of the square crop - 4 bytes
    private let _padding: UInt32 = 0 // Padding to align to 16 bytes for Metal shader - 4 bytes

    var bufferIndex: Int { 0 }
}
