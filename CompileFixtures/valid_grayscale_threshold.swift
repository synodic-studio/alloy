// EXPECT-COMPILE-SUCCESS
//
// The composable two-step path: grayscale first (colour → intensity), then a
// hard threshold (intensity → binary), then erosion. threshold is offered only
// on Grayscale, matching the model that binary comes *from* a grayscale image.

import Alloy
import Foundation

func validGrayscaleThenThreshold(data: Data) throws {
    _ = try Pipeline.rgba(width: 512, height: 512)
        .grayscale(strategy: .maxChannelRG)
        .threshold(0.4)
        .erosion(iterations: 1)
        .run(on: data)
}
