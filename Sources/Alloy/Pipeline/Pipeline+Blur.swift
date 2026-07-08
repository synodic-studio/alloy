//
//  Pipeline+Blur.swift
//  Alloy
//
//  Blur is state-preserving on colour and grayscale images, but *demotes* a
//  binary image back to grayscale — blurring white-blobs-on-black destroys the
//  binariness that `erosion`/`connectedComponents` depend on. Encoding that as
//  the return type means `…blackAndWhite().blur().connectedComponents()` fails
//  to compile (connectedComponents is offered only on Binary). This is why
//  blur can't be a single generic state-preserving op.
//

import Foundation

public extension Pipeline where State == ColorImage {
    /// Gaussian blur; preserves the colour state.
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

public extension Pipeline where State == Binary {
    /// Gaussian blur; **demotes** binary to grayscale, since a blurred binary
    /// image is no longer binary. Downstream erosion / connected-components are
    /// therefore no longer offered — by design.
    func blur(radius: Double) -> Pipeline<Grayscale> {
        appending { try $0.blur(radius: radius) }
    }
}
