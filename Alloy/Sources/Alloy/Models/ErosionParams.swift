import Metal

/// Parameters for the morphological erosion shader
struct ErosionParams: MetalShaderParameters {
    let iterations: UInt32         // Number of erosion iterations to perform - 4 bytes
    let connectivity: UInt32       // Connectivity type: 0 = 4-connection, 1 = 8-connection - 4 bytes
    
    // Padding to match Metal's alignas(16) requirement (16 bytes total needed)
    private let padding1: UInt32 = 0   // 4 bytes padding
    private let padding2: UInt32 = 0   // 4 bytes padding (total: 8 + 8 = 16 bytes)
    
    var bufferIndex: Int { 0 }
    
    init(iterations: Int, connectivity: ErosionConnectivity = .eight) {
        self.iterations = UInt32(iterations)
        self.connectivity = connectivity.metalValue
    }
}

/// Erosion connectivity options
public enum ErosionConnectivity: CaseIterable {
    case four   // 4-connected (up, down, left, right)
    case eight  // 8-connected (includes diagonals)
    
    var metalValue: UInt32 {
        switch self {
        case .four: return 0
        case .eight: return 1
        }
    }
    
    var displayName: String {
        switch self {
        case .four: return "4-Connected"
        case .eight: return "8-Connected"
        }
    }
} 