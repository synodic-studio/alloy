//
//  File.swift
//  Alloy
//
//  Created by Bryan Costanza on 6/19/25.
//

import AppKit
import Metal
import Testing

@testable import Alloy

@Suite("Grayscale Shader Computation Tests")
struct GrayscaleTests {
    // MARK: - Conversion Strategy Accuracy

    @Test("Metal weighted luminance conversion is accurate")
    func metalWeightedLuminanceConversion() throws {
        let r: CGFloat = 0.5, g: CGFloat = 0.8, b: CGFloat = 0.3
        let inputPixel = Pixel(r: r, g: g, b: b)

        let weightedSum = (0.299 * r) + (0.587 * g) + (0.114 * b)
        let expectedValue = weightedSum
        let expectedPixel = Pixel(w: expectedValue)

        try assertGrayscaleConversion(
            input: inputPixel.nsColor,
            strategy: .weighted,
            expected: expectedPixel,
        )
    }

    @Test("Metal average RGB conversion is accurate")
    func metalAverageConversion() throws {
        let r: CGFloat = 0.6, g: CGFloat = 0.9, b: CGFloat = 0.2
        let inputPixel = Pixel(r: r, g: g, b: b)
        let expectedValue = (r + g + b) / 3.0
        let expectedPixel = Pixel(w: expectedValue)

        try assertGrayscaleConversion(
            input: inputPixel.nsColor,
            strategy: .average,
            expected: expectedPixel,
        )
    }

    @Test("Metal red channel conversion is accurate")
    func metalRedChannelConversion() throws {
        let r: CGFloat = 0.7, g: CGFloat = 0.4, b: CGFloat = 0.9
        let inputPixel = Pixel(r: r, g: g, b: b)

        try assertGrayscaleConversion(
            input: inputPixel.nsColor,
            strategy: .redChannel,
            expected: Pixel(w: r),
        )
    }

    @Test("Metal green channel conversion is accurate")
    func metalGreenChannelConversion() throws {
        let r: CGFloat = 0.7, g: CGFloat = 0.4, b: CGFloat = 0.9
        let inputPixel = Pixel(r: r, g: g, b: b)

        try assertGrayscaleConversion(
            input: inputPixel.nsColor,
            strategy: .greenChannel,
            expected: Pixel(w: g),
        )
    }

    @Test("Metal blue channel conversion is accurate")
    func metalBlueChannelConversion() throws {
        let r: CGFloat = 0.7, g: CGFloat = 0.4, b: CGFloat = 0.9
        let inputPixel = Pixel(r: r, g: g, b: b)

        try assertGrayscaleConversion(
            input: inputPixel.nsColor,
            strategy: .blueChannel,
            expected: Pixel(w: b),
        )
    }

    @Test("Metal max channel conversion is accurate")
    func metalMaxChannelConversion() throws {
        let r: CGFloat = 0.6, g: CGFloat = 0.2, b: CGFloat = 0.8
        let inputPixel = Pixel(r: r, g: g, b: b)
        let expectedValue = b // b is max

        try assertGrayscaleConversion(
            input: inputPixel.nsColor,
            strategy: .maxChannel,
            expected: Pixel(w: expectedValue),
        )
    }

    @Test("Metal min channel conversion is accurate")
    func metalMinChannelConversion() throws {
        let r: CGFloat = 0.6, g: CGFloat = 0.2, b: CGFloat = 0.8
        let inputPixel = Pixel(r: r, g: g, b: b)
        let expectedValue = g // g is min

        try assertGrayscaleConversion(
            input: inputPixel.nsColor,
            strategy: .minChannel,
            expected: Pixel(w: expectedValue),
        )
    }

    // MARK: - Threshold Accuracy

    @Test("Metal black threshold remaps correctly")
    func metalBlackThresholdRemapping() throws {
        let inputPixel = Pixel(w: 0.6)
        let expectedValue = (0.6 - 0.2) / (1.0 - 0.2)

        try assertGrayscaleConversion(
            input: inputPixel.nsColor,
            strategy: .average,
            blackThreshold: 0.2,
            whiteThreshold: 1.0,
            expected: Pixel(w: expectedValue),
        )
    }

    @Test("Metal combined black and white thresholds remap correctly")
    func metalCombinedThresholdRemapping() throws {
        let inputPixel = Pixel(w: 0.5)
        let expectedValue = ((0.5 - 0.2) / (0.8 - 0.2))

        try assertGrayscaleConversion(
            input: inputPixel.nsColor,
            strategy: .average,
            blackThreshold: 0.2,
            whiteThreshold: 0.8,
            expected: Pixel(w: expectedValue),
        )
    }

    @Test("Metal value below black threshold returns zero")
    func metalValueBelowBlackThreshold() throws {
        let inputPixel = Pixel(w: 0.1)

        try assertGrayscaleConversion(
            input: inputPixel.nsColor,
            strategy: .average,
            blackThreshold: 0.2,
            whiteThreshold: 0.8,
            expected: Pixel(w: 0.0),
        )
    }

    @Test("Metal value above white threshold returns one")
    func metalValueAboveWhiteThreshold() throws {
        let inputPixel = Pixel(w: 0.9)

        try assertGrayscaleConversion(
            input: inputPixel.nsColor,
            strategy: .average,
            blackThreshold: 0.2,
            whiteThreshold: 0.8,
            expected: Pixel(w: 1.0),
        )
    }

    // MARK: - Single-Point (Binary) Threshold

    @Test("Metal single-point threshold below cutoff returns zero")
    func metalSinglePointThresholdBelowCutoff() throws {
        let inputPixel = Pixel(w: 0.4)

        try assertGrayscaleConversion(
            input: inputPixel.nsColor,
            strategy: .average,
            blackThreshold: 0.5,
            whiteThreshold: 0.5,
            expected: Pixel(w: 0.0),
        )
    }

    @Test("Metal single-point threshold above cutoff returns one")
    func metalSinglePointThresholdAtOrAboveCutoff() throws {
        // Not testing the exact boundary (w == threshold): 8-bit texture
        // quantization can round 0.5 down to 127/255 (≈0.498), which is a
        // property of the texture format, not the threshold logic.
        try assertGrayscaleConversion(
            input: Pixel(w: 0.9).nsColor,
            strategy: .average,
            blackThreshold: 0.5,
            whiteThreshold: 0.5,
            expected: Pixel(w: 1.0),
        )
    }

    @Test("Metal single-point threshold at 1.0 does not throw")
    func metalSinglePointThresholdAtMax() throws {
        try assertGrayscaleConversion(
            input: Pixel(w: 1.0).nsColor,
            strategy: .average,
            blackThreshold: 1.0,
            whiteThreshold: 1.0,
            expected: Pixel(w: 1.0),
        )
    }

    // MARK: - Validation

    @Test("Metal engine validation throws for bad thresholds")
    func metalEngineValidation() throws {
        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }

        // Test invalid black threshold
        #expect(throws: MetalEngineError.self) {
            try engine.grayscale(strategy: .average, blackThreshold: -0.1)
        }

        // Test invalid white threshold
        #expect(throws: MetalEngineError.self) {
            try engine.grayscale(strategy: .average, whiteThreshold: 1.1)
        }

        // Test black >= white threshold
        #expect(throws: MetalEngineError.self) {
            try engine.grayscale(strategy: .average, blackThreshold: 0.8, whiteThreshold: 0.5)
        }
    }

    // MARK: - Helper Methods

    /// Generic assertion to test a grayscale conversion.
    private func assertGrayscaleConversion(
        input: NSColor,
        strategy: GrayscaleConversionStrategy,
        blackThreshold: Double = 0.0,
        whiteThreshold: Double = 1.0,
        expected: Pixel,
    ) throws {
        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }

        let result = try engine
            .withRGBAData(width: 1, height: 1)
            .grayscale(
                strategy: strategy,
                blackThreshold: blackThreshold,
                whiteThreshold: whiteThreshold,
            )
            .execute(data: data(from: input))

        let outputPixels = try pixels(from: result.texture)
        #expect(outputPixels.count == 1)
        guard let firstPixel = outputPixels.first else {
            #expect(Bool(false), "Failed to get output pixel")
            return
        }

        #expect(
            firstPixel.isApproximatelyEqual(to: expected, tolerance: 1),
            "Conversion failed for \(strategy). Expected \(expected), got \(firstPixel)",
        )
    }

    /// Creates a 1x1 image Data object from a single NSColor.
    private func data(from color: NSColor) -> Data {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0

        // Convert to RGB colorspace if needed to avoid colorspace conversion errors
        let rgbColor = color.usingColorSpace(.deviceRGB) ?? color
        rgbColor.getRed(&r, green: &g, blue: &b, alpha: &a)

        return Data([
            UInt8(r * 255),
            UInt8(g * 255),
            UInt8(b * 255),
            UInt8(a * 255),
        ])
    }

    /// Reads the pixel data from an MTLTexture.
    private func pixels(from texture: MTLTexture) throws -> [Pixel] {
        let width = texture.width
        let height = texture.height

        guard texture.pixelFormat == .rgba8Uint else {
            throw TestError.unsupportedPixelFormat(texture.pixelFormat)
        }

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let size = bytesPerRow * height
        var data = Data(count: size)

        data.withUnsafeMutableBytes { ptr in
            texture.getBytes(
                ptr.baseAddress!,
                bytesPerRow: bytesPerRow,
                from: MTLRegionMake2D(0, 0, width, height),
                mipmapLevel: 0,
            )
        }

        var pixels: [Pixel] = []
        for i in stride(from: 0, to: data.count, by: 4) {
            pixels.append(Pixel(r: data[i], g: data[i + 1], b: data[i + 2], a: data[i + 3]))
        }

        return pixels
    }

    enum TestError: Error {
        case engineInitializationFailed
        case unsupportedPixelFormat(MTLPixelFormat)
    }
}

private struct Pixel: Equatable {
    let r, g, b, a: UInt8

    init(
        r: UInt8,
        g: UInt8,
        b: UInt8,
        a: UInt8 = 255,
    ) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    init(
        r: Double,
        g: Double,
        b: Double,
        a: Double = 1.0,
    ) {
        self.r = UInt8(r * 255)
        self.g = UInt8(g * 255)
        self.b = UInt8(b * 255)
        self.a = UInt8(a * 255)
    }

    init(
        w: UInt8,
        a: UInt8 = 255,
    ) {
        r = w
        g = w
        b = w
        self.a = a
    }

    init(
        w: Double,
        a: Double = 1.0,
    ) {
        r = UInt8(w * 255)
        g = UInt8(w * 255)
        b = UInt8(w * 255)
        self.a = UInt8(a * 255)
    }

    /// Checks if two pixels are approximately equal, within a given tolerance.
    func isApproximatelyEqual(to other: Pixel, tolerance: Int = 1) -> Bool {
        abs(Int(r) - Int(other.r)) <= tolerance &&
            abs(Int(g) - Int(other.g)) <= tolerance &&
            abs(Int(b) - Int(other.b)) <= tolerance &&
            abs(Int(a) - Int(other.a)) <= tolerance
    }
}

extension Pixel {
    var nsColor: NSColor {
        NSColor(
            red: CGFloat(r) / 255.0,
            green: CGFloat(g) / 255.0,
            blue: CGFloat(b) / 255.0,
            alpha: CGFloat(a) / 255.0,
        )
    }
}
