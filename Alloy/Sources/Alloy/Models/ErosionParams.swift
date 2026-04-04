import Metal

/// Parameters for the morphological erosion shader
struct ErosionParams: MetalShaderParameters {
    let iterations: UInt32 // Number of erosion iterations to perform - 4 bytes
    let connectivity: UInt32 // Connectivity type: 0 = 4-connection, 1 = 8-connection - 4 bytes
    private let _padding: SIMD2<UInt32> = SIMD2<UInt32>(0, 0) // Padding to align to 16 bytes - 8 bytes

    var bufferIndex: Int { 0 }

    init(iterations: Int, connectivity: ErosionConnectivity = .eight) {
        self.iterations = UInt32(iterations)
        self.connectivity = connectivity.metalValue
    }
}

/// Erosion connectivity options
public enum ErosionConnectivity: CaseIterable {
    case four // 4-connected (up, down, left, right)
    case eight // 8-connected (includes diagonals)

    var metalValue: UInt32 {
        switch self {
        case .four: 0
        case .eight: 1
        }
    }

    var displayName: String {
        switch self {
        case .four: "4-Connected"
        case .eight: "8-Connected"
        }
    }
}
