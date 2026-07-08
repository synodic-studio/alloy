//
//  Pipeline+PeakDetection.swift
//  Alloy
//

import Foundation

public extension Pipeline where State == Grayscale {
    /// Terminal: detect local intensity maxima on the grayscale image and
    /// return the marked visualization image. Offered only on `Grayscale`.
    func peakDetection(
        on data: Data,
        neighborhoodSize: Int = 3,
        threshold: Double = 0.5,
    ) throws -> BaseShaderResult {
        let engine = try makeConfiguredEngine()
        _ = try engine.peakDetection(neighborhoodSize: neighborhoodSize, threshold: threshold)
        return try engine.execute(data: data)
    }
}
