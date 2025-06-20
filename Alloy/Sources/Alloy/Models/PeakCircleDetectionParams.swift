import Metal

/// Parameters for the peak finding circle detection shader
struct PeakCircleDetectionParams: MetalShaderParameters {
    let minRadius: UInt32          // Minimum circle radius to detect - 4 bytes
    let maxRadius: UInt32          // Maximum circle radius to detect - 4 bytes
    let correlationThreshold: Float // Correlation threshold (0.0-1.0) - 4 bytes
    let maxPeaks: UInt32           // Maximum number of peaks to detect - 4 bytes
    
    var bufferIndex: Int { 0 }
    
    init(minDiameter: Int, maxDiameter: Int, correlationThreshold: Float = 0.7, maxPeaks: Int = 100) {
        self.minRadius = UInt32(minDiameter / 2)
        self.maxRadius = UInt32(maxDiameter / 2)
        self.correlationThreshold = correlationThreshold
        self.maxPeaks = UInt32(maxPeaks)
    }
} 