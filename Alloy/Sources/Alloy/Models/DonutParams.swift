import Metal

/// Parameters for the donut mask shader
struct DonutParams: MetalShaderParameters {
    let center: SIMD2<UInt32> // Center of the donut (x, y) - 8 bytes
    let innerRadius: UInt32 // Inner radius of the donut - 4 bytes
    private let _padding: UInt32 = 0 // Padding to align to 16 bytes for Metal shader - 4 bytes

    var bufferIndex: Int { 0 }
}
