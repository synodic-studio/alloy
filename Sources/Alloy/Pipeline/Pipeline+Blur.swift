//
//  Pipeline+Blur.swift
//  Alloy
//
//  Blur is offered only on color and grayscale images, where it is state-
//  preserving. It is deliberately NOT offered on Binary: blurring destroys the
//  binariness that erosion/connectedComponents depend on. To blur a binary
//  image, first relax it with `.asGrayscale()` — an explicit, zero-cost step
//  that spells out "I am leaving the binary world."
//

import Foundation

public extension Pipeline where State == ColorImage {
    /// Gaussian blur; preserves the color state.
    func blur(radius: Double) -> Pipeline<ColorImage> {
        appending { try $0.blur(radius: radius) }
    }
}

public extension Pipeline where State == Grayscale {
    /// Gaussian blur; preserves the grayscale state.
    func blur(radius: Double) -> Pipeline<Grayscale> {
        appending { try $0.blur(radius: radius) }
    }
}
