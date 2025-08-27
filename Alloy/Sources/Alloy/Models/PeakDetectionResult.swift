import Metal

/// Result type for peak detection operations containing both processed texture and detected peaks
public struct PeakDetectionResult: MetalShaderResult {
    public let texture: MTLTexture
    public let width: Int
    public let height: Int
    public let detectedPeaks: [DetectedPeak]

    public init(texture: MTLTexture, width: Int, height: Int, detectedPeaks: [DetectedPeak]) {
        self.texture = texture
        self.width = width
        self.height = height
        self.detectedPeaks = detectedPeaks
    }

    /// Number of peaks detected
    public var peakCount: Int {
        detectedPeaks.count
    }
}
