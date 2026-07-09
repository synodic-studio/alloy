//
//  Pipeline+Noise.swift
//  Alloy
//
//  Noise injection, like blur, is offered only on color and grayscale images
//  (state-preserving). It is not offered on Binary — noise destroys binariness.
//  To noise a binary image, relax it first with `.asGrayscale()`.
//

import Foundation

public extension Pipeline where State == ColorImage {
    /// Inject random noise; preserves the color state.
    func noise(
        magnitude: Double,
        seed: UInt32? = nil,
        ignoreBlack: Bool = false,
        ignoreWhite: Bool = false,
    ) -> Pipeline<ColorImage> {
        appending {
            try $0.noise(magnitude: magnitude, seed: seed, ignoreBlack: ignoreBlack, ignoreWhite: ignoreWhite)
        }
    }
}

public extension Pipeline where State == Grayscale {
    /// Inject random noise; preserves the grayscale state.
    func noise(
        magnitude: Double,
        seed: UInt32? = nil,
        ignoreBlack: Bool = false,
        ignoreWhite: Bool = false,
    ) -> Pipeline<Grayscale> {
        appending {
            try $0.noise(magnitude: magnitude, seed: seed, ignoreBlack: ignoreBlack, ignoreWhite: ignoreWhite)
        }
    }
}
