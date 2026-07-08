// EXPECT-COMPILE-FAILURE
//
// Blur demotes a binary image back to grayscale (blurring destroys the
// binariness erosion/connectedComponents rely on). So after blur, the pipeline
// is Pipeline<Grayscale>, and connectedComponents — offered only on Binary — is
// no longer available. This ordering is a compile error, not silent garbage.

import Alloy
import Foundation

func invalidBlurThenConnectedComponents(data: Data) throws {
    _ = try Pipeline.rgba(width: 512, height: 512)
        .blackAndWhite(threshold: 0.5)
        .blur(radius: 2)
        .connectedComponents(on: data, maxComponents: 20)
}
