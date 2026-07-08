//
//  Pipeline+ConnectedComponents.swift
//  Alloy
//

import Foundation

public extension Pipeline where State == Binary {
    /// Terminal analysis: run connected components over the binary image and
    /// return detected blob centroids.
    ///
    /// Respects every upstream stage by executing the recorded chain to a
    /// binary texture, then feeding that texture straight into the
    /// connected-components pass (no GPU→CPU roundtrip), mirroring
    /// GravityWell's per-frame detection path.
    func connectedComponents(
        on data: Data,
        maxComponents: Int = 50,
        maxPixelsPerBlob: Int = 100,
    ) throws -> ConnectedComponentsResult {
        let engine = try makeConfiguredEngine()
        let binary = try engine.execute(data: data)
        return try engine.executeConnectedComponentsWithTexture(
            inputTexture: binary.texture,
            maxComponents: maxComponents,
            maxPixelsPerBlob: maxPixelsPerBlob,
        )
    }
}
