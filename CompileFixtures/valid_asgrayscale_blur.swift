// EXPECT-COMPILE-SUCCESS
//
// The explicit path compiles: relax the binary image to grayscale, then blur.
// This is the intended way to leave the binary world — spelled out, not silent.

import Alloy
import Foundation

func validAsGrayscaleThenBlur(data: Data) throws {
    _ = try Pipeline.rgba(width: 512, height: 512)
        .blackAndWhite(threshold: 0.5)
        .asGrayscale()
        .blur(radius: 2)
        .run(on: data)
}
