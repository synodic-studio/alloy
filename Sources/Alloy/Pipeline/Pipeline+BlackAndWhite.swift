//
//  Pipeline+BlackAndWhite.swift
//  Alloy
//

import Foundation

public extension Pipeline where State == ColorImage {
    /// Threshold the colour image into a binary (black-and-white) image using a
    /// hard cutoff (equal black/white thresholds — no ramp).
    ///
    /// Advances the pipeline to `Binary`, unlocking `erosion` and
    /// `connectedComponents`. `strategy` selects the channel weighting used to
    /// derive intensity before the cutoff (default luminance-weighted); pass the
    /// same strategy the untyped `grayscale(strategy:blackThreshold:whiteThreshold:)`
    /// call used, so output is identical.
    func blackAndWhite(
        strategy: GrayscaleConversionStrategy = .weighted,
        threshold: Double,
    ) -> Pipeline<Binary> {
        appending {
            try $0.grayscale(strategy: strategy, blackThreshold: threshold, whiteThreshold: threshold)
        }
    }
}
