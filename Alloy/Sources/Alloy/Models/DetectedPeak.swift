import simd

/// Internal representation of a detected peak from Metal peak finding
struct DetectedPeak {
    let position: SIMD2<Float>
    let correlation: Float
    let radius: Float
    
    init(position: SIMD2<Float>, correlation: Float, radius: Float) {
        self.position = position
        self.correlation = correlation
        self.radius = radius
    }
    
    /// Convert to DetectedCircle for public API
    var detectedCircle: DetectedCircle {
        return DetectedCircle(
            x: position.x,
            y: position.y,
            diameter: radius * 2.0,
            confidence: correlation
        )
    }
} 