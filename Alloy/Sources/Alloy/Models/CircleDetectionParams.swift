import Metal

/// Parameters for the Sobel edge-based circle detection shader
struct SobelCircleDetectionParams: MetalShaderParameters {
    let minRadius: UInt32          // Minimum circle radius to detect - 4 bytes
    let maxRadius: UInt32          // Maximum circle radius to detect - 4 bytes
    let threshold: Float           // Edge detection threshold (0.0-1.0) - 4 bytes
    let maxCircles: UInt32         // Maximum number of circles to detect - 4 bytes
    
    var bufferIndex: Int { 0 }
    
    init(minDiameter: Int, maxDiameter: Int, threshold: Float = 0.5, maxCircles: Int = 100) {
        self.minRadius = UInt32(minDiameter / 2)
        self.maxRadius = UInt32(maxDiameter / 2)
        self.threshold = threshold
        self.maxCircles = UInt32(maxCircles)
    }
} 