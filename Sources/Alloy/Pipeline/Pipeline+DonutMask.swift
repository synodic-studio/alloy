//
//  Pipeline+DonutMask.swift
//  Alloy
//

import Foundation

public extension Pipeline where State: DevelopedImage {
    /// Apply a circular donut mask (black outside the ring). State-preserving;
    /// offered on any `DevelopedImage`, never on raw Bayer data.
    func donutMask(
        center: (x: Int, y: Int)? = nil,
        innerRadius: Int,
        featherPixels: Float = 0,
    ) -> Pipeline<State> {
        appending {
            try $0.donutMask(center: center, innerRadius: innerRadius, featherPixels: featherPixels)
        }
    }
}
