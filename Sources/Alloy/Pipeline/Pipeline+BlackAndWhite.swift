//
//  Pipeline+BlackAndWhite.swift
//  Alloy
//
//  `blackAndWhite` produces a binary image. It is overloaded by input state:
//  from a color image it also needs a channel `strategy` (it fuses the
//  grayscale collapse and the hard cut into one GPU pass); from an image that
//  is already grayscale, no strategy is needed — it's just the cut. Both reach
//  `Binary`, and the fused color form is byte-identical to grayscale(strategy)
//  followed by the grayscale cut (proven in PipelineTests).
//

import Foundation

public extension Pipeline where State == ColorImage {
    /// Convert a color image straight to binary: collapse channels with
    /// `strategy`, then hard-cut at `threshold`. This is FUSED into a single GPU
    /// pass (Alloy's grayscale shader does collapse + cut together), so it's the
    /// efficient path when you don't need the intermediate grayscale image.
    func blackAndWhite(
        strategy: GrayscaleConversionStrategy = .weighted,
        threshold: Double,
    ) -> Pipeline<Binary> {
        appending {
            try $0.grayscale(strategy: strategy, blackThreshold: threshold, whiteThreshold: threshold)
        }
    }
}

public extension Pipeline where State == Grayscale {
    /// Hard-cut an already-grayscale image into binary. No strategy — the
    /// channel collapse already happened (via `grayscale(strategy:)`), so this
    /// is purely the cut. The composable second half of color → gray → binary,
    /// and the way to binarize an image you already made grayscale (e.g. after
    /// blur).
    func blackAndWhite(threshold: Double) -> Pipeline<Binary> {
        appending { try $0.blackAndWhite(threshold: threshold) }
    }
}
