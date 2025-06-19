import Metal

/// Parameters for HSV-based pixel positioning shader
struct HSVPositionParams: MetalShaderParameters {
    let xComponent: UInt32      // HSV component for X axis (0=H, 1=S, 2=V) - 4 bytes
    let yComponent: UInt32      // HSV component for Y axis (0=H, 1=S, 2=V) - 4 bytes
    let outputWidth: UInt32     // Output texture width - 4 bytes
    let outputHeight: UInt32    // Output texture height - 4 bytes
    let reverseX: UInt32        // 1 to reverse X axis direction, 0 for normal - 4 bytes
    let reverseY: UInt32        // 1 to reverse Y axis direction, 0 for normal - 4 bytes
    let noiseAmount: Float      // Amount of random noise to add (in pixels) - 4 bytes
    let pixelSize: UInt32       // Size of each plotted pixel (width and height) - 4 bytes
    let forceFullValue: UInt32  // 1 to force value to full (1.0), 0 for normal - 4 bytes
    let forceFullSaturation: UInt32 // 1 to force saturation to full (1.0), 0 for normal - 4 bytes
    
    // Padding to match Metal's alignas(16) requirement (48 bytes total, need 16-byte alignment)
    private let padding1: UInt32 = 0    // 4 bytes padding
    private let padding2: UInt32 = 0    // 4 bytes padding (total: 40 + 8 = 48 bytes)
    
    var bufferIndex: Int { 0 }
} 