//
//  Pipeline+Threshold.swift
//  Alloy
//
//  Thresholding an image that is ALREADY grayscale into binary. The channel
//  collapse already happened (via `grayscale(strategy:)`), so no strategy is
//  needed here — this is the pure hard cutoff. Grayscale → Binary.
//
//  This is the composable, two-step path (`.grayscale(strategy:).threshold(t)`).
//  `blackAndWhite(strategy:threshold:)` on `ColorImage` is the fused one-pass
//  equivalent for the common colour-straight-to-binary case; the two produce
//  identical output (proven in PipelineTests).
//

import Foundation

public extension Pipeline where State == Grayscale {
    /// Threshold this intensity image into binary at a hard cutoff.
    func threshold(_ cutoff: Double) -> Pipeline<Binary> {
        appending { try $0.blackAndWhite(threshold: cutoff) }
    }
}
