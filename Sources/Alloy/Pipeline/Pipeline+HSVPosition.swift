//
//  Pipeline+HSVPosition.swift
//  Alloy
//
//  HSV-position mapping is a visualization terminal: it remaps a color image
//  into an HSV-position plot for display, not a stage you keep chaining. Offered
//  only on ColorImage; returns the rendered image.
//

import Foundation

public extension Pipeline where State == ColorImage {
    /// General HSV-position mapping. Terminal.
    func hsvPosition(
        on data: Data,
        xAxis: HSVAxis,
        yAxis: HSVAxis,
        width: Int? = nil,
        height: Int? = nil,
        reverseX: Bool = false,
        reverseY: Bool = false,
        noiseAmount: Float = 10.0,
        pixelSize: Int = 1,
        forceFullValue: Bool = false,
        forceFullSaturation: Bool = false,
    ) throws -> BaseShaderResult {
        let engine = try makeConfiguredEngine()
        _ = try engine.hsvPosition(
            xAxis: xAxis,
            yAxis: yAxis,
            width: width,
            height: height,
            reverseX: reverseX,
            reverseY: reverseY,
            noiseAmount: noiseAmount,
            pixelSize: pixelSize,
            forceFullValue: forceFullValue,
            forceFullSaturation: forceFullSaturation,
        )
        return try engine.execute(data: data)
    }

    /// Saturation (x) × Value (y) plot. Terminal.
    func hsvPositionSaturationValue(on data: Data, pixelSize: Int = 1) throws -> BaseShaderResult {
        let engine = try makeConfiguredEngine()
        _ = try engine.hsvPositionSaturationValue(pixelSize: pixelSize)
        return try engine.execute(data: data)
    }

    /// Hue (x) × Value (y) plot. Terminal.
    func hsvPositionHueValue(
        on data: Data,
        pixelSize: Int = 1,
        forceFullSaturation: Bool = false,
    ) throws -> BaseShaderResult {
        let engine = try makeConfiguredEngine()
        _ = try engine.hsvPositionHueValue(pixelSize: pixelSize, forceFullSaturation: forceFullSaturation)
        return try engine.execute(data: data)
    }

    /// Hue (x) × Saturation (y) plot. Terminal.
    func hsvPositionHueSaturation(
        on data: Data,
        pixelSize: Int = 1,
        forceFullValue: Bool = false,
    ) throws -> BaseShaderResult {
        let engine = try makeConfiguredEngine()
        _ = try engine.hsvPositionHueSaturation(pixelSize: pixelSize, forceFullValue: forceFullValue)
        return try engine.execute(data: data)
    }
}
