// EXPECT-COMPILE-FAILURE
//
// Erosion must not be reachable before thresholding. `Pipeline<Color>` has no
// member `erosion` — only `Pipeline<Binary>` (State: BlackAndWhite) does — so
// this ordering is a compile-time "value of type 'Pipeline<Color>' has no
// member 'erosion'" error, not silent runtime garbage.

import Alloy

func invalidErosionBeforeThreshold() {
    _ = Pipeline.rgba(width: 512, height: 512)
        .erosion(iterations: 1)
}
