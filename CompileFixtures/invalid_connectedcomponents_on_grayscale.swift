// EXPECT-COMPILE-FAILURE
//
// connectedComponents is a terminal offered only on Pipeline<Binary>. A
// grayscale image has not been thresholded, so blob analysis is meaningless —
// and here a compile error, not runtime garbage. Reaching Binary requires
// blackAndWhite(threshold:), not grayscale(strategy:).

import Alloy
import Foundation

func invalidConnectedComponentsOnGrayscale(data: Data) throws {
    _ = try Pipeline.rgba(width: 512, height: 512)
        .grayscale(strategy: .weighted)
        .connectedComponents(on: data, maxComponents: 20)
}
