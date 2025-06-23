import Metal

/// Parameters for the peak detection shader
struct PeakDetectionParams: MetalShaderParameters {
    let neighborhoodSize: UInt32   // 8 or 16 neighbors - 4 bytes
    let minDistance: Float         // Minimum distance between peaks - 4 bytes
    let maxPeaks: UInt32           // Maximum number of peaks to detect - 4 bytes
    let threshold: Float           // Minimum intensity for a peak (0.0 - 1.0) - 4 bytes
    
    var bufferIndex: Int { 0 }
    
    init(neighborhoodSize: Int = 8, minDistance: Double = 5.0, maxPeaks: Int = 100, threshold: Double = 0.5) {
        self.neighborhoodSize = UInt32(neighborhoodSize)
        self.minDistance = Float(minDistance)
        self.maxPeaks = UInt32(maxPeaks)
        self.threshold = Float(threshold)
    }
} 