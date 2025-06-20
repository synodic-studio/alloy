import Foundation

/// Represents a detected circle with position and size
public struct DetectedCircle: Sendable {
    public let x: Float
    public let y: Float
    public let diameter: Float
    public let confidence: Float  // Confidence score for the detection
    
    public init(x: Float, y: Float, diameter: Float, confidence: Float = 1.0) {
        self.x = x
        self.y = y
        self.diameter = diameter
        self.confidence = confidence
    }
    
    /// Radius of the circle
    public var radius: Float {
        return diameter / 2.0
    }
    
    /// Center point as a tuple
    public var center: (x: Float, y: Float) {
        return (x: x, y: y)
    }
} 