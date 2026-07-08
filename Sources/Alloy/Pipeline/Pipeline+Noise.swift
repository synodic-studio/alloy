//
//  Pipeline+Noise.swift
//  Alloy
//
//  Noise injection, like blur, preserves colour/grayscale state but demotes
//  binary to grayscale (a noised binary image is no longer binary). Same
//  per-state typing as blur — see Pipeline+Blur.swift.
//

import Foundation

public extension Pipeline where State == ColorImage {
    /// Inject random noise; preserves the colour state.
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

public extension Pipeline where State == Binary {
    /// Inject random noise; **demotes** binary to grayscale (a noised binary
    /// image is no longer binary), so downstream binary ops are not offered.
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
