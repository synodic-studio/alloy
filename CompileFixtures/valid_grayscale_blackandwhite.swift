// EXPECT-COMPILE-SUCCESS
//
// The composable two-step path: grayscale first (colour → intensity), then the
// strategy-free blackAndWhite cut (intensity → binary), then erosion. The
// Grayscale overload of blackAndWhite needs no strategy — the collapse already
// happened — matching the model that binary comes *from* a grayscale image.

import Alloy
import Foundation

func validGrayscaleThenBlackAndWhite(data: Data) throws {
    _ = try Pipeline.rgba(width: 512, height: 512)
        .grayscale(strategy: .maxChannelRG)
        .blackAndWhite(threshold: 0.4)
        .erosion(iterations: 1)
        .run(on: data)
}
