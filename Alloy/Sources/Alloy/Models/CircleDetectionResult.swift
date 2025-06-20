import Metal

/// Result type for circle detection operations containing both processed texture and detected circles
public struct CircleDetectionResult: MetalShaderResult {
    public let texture: MTLTexture
    public let width: Int
    public let height: Int
    public let detectedCircles: [DetectedCircle]
    
    public init(texture: MTLTexture, width: Int, height: Int, detectedCircles: [DetectedCircle]) {
        self.texture = texture
        self.width = width
        self.height = height
        self.detectedCircles = detectedCircles
    }
    
    /// Number of circles detected
    public var circleCount: Int {
        return detectedCircles.count
    }
} 