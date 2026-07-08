//
//  Pipeline+Debayer.swift
//  Alloy
//

import Foundation

public extension Pipeline where State == RawBayer {
    /// Entry point: a pipeline seeded with raw Bayer sensor data.
    static func rawBayer(width: Int, height: Int, bitDepth: Int = 8) -> Pipeline<RawBayer> {
        Pipeline<RawBayer>(width: width, height: height) {
            guard let engine = CommonMetalEngine() else {
                throw MetalEngineError.generalError(message: "Failed to create Metal engine")
            }
            return try engine.withRawData(width: width, height: height, bitDepth: bitDepth)
        }
    }

    /// Demosaic RGGB Bayer data into a full-colour image. The only operation
    /// offered on `RawBayer`, and the only way to reach `ColorImage` from raw.
    func debayerRGGB(bitDepth: Int? = nil) -> Pipeline<ColorImage> {
        appending { try $0.debayerRGGB(bitDepth: bitDepth) }
    }
}
