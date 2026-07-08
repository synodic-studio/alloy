// EXPECT-COMPILE-FAILURE
//
// Blur is not offered on Binary at all — blurring destroys binariness. You must
// explicitly relax the type first with `.asGrayscale()`. So `.blackAndWhite()
// .blur()` is a compile error ("Pipeline<Binary> has no member 'blur'"), which
// forces the intent to be spelled out rather than silently changing the type.

import Alloy

func invalidBlurOnBinary() {
    _ = Pipeline.rgba(width: 512, height: 512)
        .blackAndWhite(threshold: 0.5)
        .blur(radius: 2)
}
