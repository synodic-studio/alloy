//
//  Pipeline+BlackAndWhite.swift
//  Alloy
//

import Foundation

public extension Pipeline where State == ColorImage {
    /// Threshold the colour image into a binary (black-and-white) image.
    ///
    /// Advances the pipeline to `Binary`, unlocking `erosion` and
    /// `connectedComponents`. Delegates to the identical shader as
    /// `CommonMetalEngine.blackAndWhite(threshold:)`.
    func blackAndWhite(threshold: Double) -> Pipeline<Binary> {
        appending { try $0.blackAndWhite(threshold: threshold) }
    }
}
