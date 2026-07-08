// EXPECT-COMPILE-SUCCESS
//
// The full linear pipeline type-checks end to end: raw Bayer → debayer →
// geometric ops → grayscale → threshold → erosion → connectedComponents.
// Control proving the expanded state graph accepts every valid transition.

import Alloy
import Foundation

func validRawChain(data: Data) throws {
    _ = try Pipeline.rawBayer(width: 1024, height: 1024, bitDepth: 16)
        .debayerRGGB()
        .squareCrop(center: (x: 512, y: 512), sideLength: 400)
        .donutMask(innerRadius: 40)
        .blackAndWhite(threshold: 0.5)
        .erosion(iterations: 1)
        .connectedComponents(on: data, maxComponents: 20)
}
