// EXPECT-COMPILE-SUCCESS
//
// The intended ordering type-checks: rgba → blackAndWhite (→ Binary) → erosion.
// Control case proving the fixture harness accepts valid pipelines, not just
// that it rejects invalid ones.

import Alloy
import Foundation

func validChain(data: Data) throws {
    _ = try Pipeline.rgba(width: 512, height: 512)
        .blackAndWhite(threshold: 0.5)
        .erosion(iterations: 2)
        .run(on: data)
}
