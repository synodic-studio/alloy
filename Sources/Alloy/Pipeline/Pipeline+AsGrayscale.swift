//
//  Pipeline+AsGrayscale.swift
//  Alloy
//

import Foundation

public extension Pipeline where State == Binary {
    /// Reinterpret this binary image as a general grayscale image — a zero-cost
    /// type relaxation. A binary image is already a valid grayscale image (every
    /// pixel is 0 or 255), so no shader runs; only the phantom state changes.
    ///
    /// Use this to *deliberately* leave the binary world before an operation
    /// that would destroy binariness (blur, noise). Making the demotion explicit
    /// keeps those ops off `Binary` entirely, so `.blur()` can never silently
    /// turn a binary image into something `erosion`/`connectedComponents` will
    /// then quietly mis-handle.
    func asGrayscale() -> Pipeline<Grayscale> {
        appending { $0 } // identity: no engine op appended, only the type changes
    }
}
