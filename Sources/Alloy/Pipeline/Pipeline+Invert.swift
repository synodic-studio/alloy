//
//  Pipeline+Invert.swift
//  Alloy
//

import Foundation

public extension Pipeline where State: DevelopedImage {
    /// Invert colors. State-preserving; offered on any `DevelopedImage`,
    /// never on raw Bayer data.
    func invert() -> Pipeline<State> {
        appending { try $0.invert() }
    }
}
