import simd

/// Represents a detected peak with position and value
public struct DetectedPeak: Sendable {
    public let x: Float
    public let y: Float
    public let value: Float // Peak intensity value

    public var position: SIMD2<Float> {
        SIMD2<Float>(x, y)
    }
}
