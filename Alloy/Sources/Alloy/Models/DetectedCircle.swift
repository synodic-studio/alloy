import simd

/// Represents a detected circle with position and size
public struct DetectedCircle: Sendable {
    public let x: Float
    public let y: Float
    public let diameter: Float
    public let confidence: Float  // Confidence score for the detection
    
    /// Radius of the circle
    public var radius: Float {
        return diameter / 2.0
    }
    
    public var position: SIMD2<Float> {
        return SIMD2<Float>(x, y)
    }
} 