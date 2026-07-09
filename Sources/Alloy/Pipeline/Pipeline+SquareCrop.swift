//
//  Pipeline+SquareCrop.swift
//  Alloy
//

import Foundation

public extension Pipeline where State: DevelopedImage {
    /// Extract a square region around a centre point. State-preserving: a crop
    /// of a color image is still color, of a binary image still binary.
    /// Offered on any `DevelopedImage`, never on raw Bayer data.
    func squareCrop(center: (x: Int, y: Int), sideLength: Int) -> Pipeline<State> {
        appending { try $0.squareCrop(center: center, sideLength: sideLength) }
    }
}
