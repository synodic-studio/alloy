//
//  Pipeline+ColorSampling.swift
//  Alloy
//
//  Color sampling is a *branching* terminal, not a linear stage: it takes the
//  color image plus a list of pixel positions and returns the colors at those
//  points — it doesn't hand back a "next state" to keep chaining. So it's
//  modelled as a terminal offered only on ColorImage, like connectedComponents
//  is on Binary.
//

import CoreGraphics
import Foundation

public extension Pipeline where State == ColorImage {
    /// Sample colors at the given positions on the (fully processed) color
    /// image. Executes the recorded chain to a color texture, then samples it
    /// on-GPU — no CPU roundtrip. Terminal.
    func sampleColors(
        on data: Data,
        at positions: [CGPoint],
        radius: Float = 3.0,
    ) throws -> ColorSamplingResult {
        let engine = try makeConfiguredEngine()
        let colorResult = try engine.execute(data: data)
        return try engine.executeSampling(inputTexture: colorResult.texture, positions: positions, radius: radius)
    }
}
