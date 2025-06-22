import simd

/// Represents a detected peak with position and value
public struct DetectedPeak: Sendable {
    public let x: Float
    public let y: Float
    public let value: Float        // Peak intensity value
    public let confidence: Float   // Confidence score for the detection
    
    public var position: SIMD2<Float> {
        return SIMD2<Float>(x, y)
    }
} 