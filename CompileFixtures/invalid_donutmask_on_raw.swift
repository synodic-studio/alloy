// EXPECT-COMPILE-FAILURE
//
// Geometric ops are offered only on DevelopedImage, never on raw Bayer data —
// masking a mosaic before debayering would corrupt it. `Pipeline<RawBayer>`
// has no member `donutMask`; the only op it offers is `debayerRGGB`.

import Alloy

func invalidDonutMaskOnRaw() {
    _ = Pipeline.rawBayer(width: 512, height: 512, bitDepth: 16)
        .donutMask(innerRadius: 20)
}
