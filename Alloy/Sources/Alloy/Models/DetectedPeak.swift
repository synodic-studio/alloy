import simd

/// Internal representation of a detected peak from Metal peak finding
public struct DetectedPeak {
    public let position: SIMD2<Float>
    public let correlation: Float
    public let radius: Float
    
    init(position: SIMD2<Float>, correlation: Float, radius: Float) {
        self.position = position
        self.correlation = correlation
        self.radius = radius
    }
    
    /// Convert to DetectedCircle for public API
    var detectedCircle: DetectedCircle {
        .init(
            x: self.position.x,
            y: self.position.y,
            diameter: self.radius * 2,
            confidence: self.correlation
        )
    }
} 