//
//  Pipeline+Grayscale.swift
//  Alloy
//

import Foundation

public extension Pipeline where State == ColorImage {
    /// Convert the colour image to single-channel grayscale using the given
    /// strategy. Advances to `Grayscale`, which unlocks `peakDetection`.
    ///
    /// This is pure grayscale — thresholding into a binary image is routed
    /// exclusively through `blackAndWhite(threshold:)` so that binariness is
    /// always tracked in the type, never left value-dependent.
    func grayscale(strategy: GrayscaleConversionStrategy) -> Pipeline<Grayscale> {
        appending { try $0.grayscale(strategy: strategy) }
    }
}
