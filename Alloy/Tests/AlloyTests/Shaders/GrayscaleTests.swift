//
//  File.swift
//  Alloy
//
//  Created by Bryan Costanza on 6/19/25.
//

import Testing
import AppKit
import Metal

@testable import Alloy

@Suite("Grayscale Shader Computation Tests")
struct GrayscaleTests {

    // MARK: - Conversion Strategy Accuracy

    @Test("Metal weighted luminance conversion is accurate")
    func testMetalWeightedLuminanceConversion() throws {
        let r: CGFloat = 0.5, g: CGFloat = 0.8, b: CGFloat = 0.3
        let inputPixel = Pixel(r: r, g: g, b: b)

        let weightedSum = (0.299 * r) + (0.587 * g) + (0.114 * b)
        let expectedValue = weightedSum
        let expectedPixel = Pixel(w: expectedValue)

        try assertGrayscaleConversion(
            input: inputPixel.nsColor,
            strategy: .weighted,
            expected: expectedPixel
        )
    }

    @Test("Metal average RGB conversion is accurate")
    func testMetalAverageConversion() throws {
        let r: CGFloat = 0.6, g: CGFloat = 0.9, b: CGFloat = 0.2
        let inputPixel = Pixel(r: r, g: g, b: b)
        let expectedValue = (r + g + b) / 3.0
        let expectedPixel = Pixel(w: expectedValue)

        try assertGrayscaleConversion(
            input: inputPixel.nsColor,
            strategy: .average,
            expected: expectedPixel
        )
    }

    @Test("Metal red channel conversion is accurate")
    func testMetalRedChannelConversion() throws {
        let r: CGFloat = 0.7, g: CGFloat = 0.4, b: CGFloat = 0.9
        let inputPixel = Pixel(r: r, g: g, b: b)
        
        try assertGrayscaleConversion(
            input: inputPixel.nsColor,
            strategy: .redChannel,
            expected: Pixel(w: r)
        )
    }
    
    @Test("Metal green channel conversion is accurate")
    func testMetalGreenChannelConversion() throws {
        let r: CGFloat = 0.7, g: CGFloat = 0.4, b: CGFloat = 0.9
        let inputPixel = Pixel(r: r, g: g, b: b)
        
        try assertGrayscaleConversion(
            input: inputPixel.nsColor,
            strategy: .greenChannel,
            expected: Pixel(w: g)
        )
    }
    
    @Test("Metal blue channel conversion is accurate")
    func testMetalBlueChannelConversion() throws {
        let r: CGFloat = 0.7, g: CGFloat = 0.4, b: CGFloat = 0.9
        let inputPixel = Pixel(r: r, g: g, b: b)
        
        try assertGrayscaleConversion(
            input: inputPixel.nsColor,
            strategy: .blueChannel,
            expected: Pixel(w: b)
        )
    }

    @Test("Metal max channel conversion is accurate")
    func testMetalMaxChannelConversion() throws {
        let r: CGFloat = 0.6, g: CGFloat = 0.2, b: CGFloat = 0.8
        let inputPixel = Pixel(r: r, g: g, b: b)
        let expectedValue = b // b is max

        try assertGrayscaleConversion(
            input: inputPixel.nsColor,
            strategy: .maxChannel,
            expected: Pixel(w: expectedValue)
        )
    }
    
    @Test("Metal min channel conversion is accurate")
    func testMetalMinChannelConversion() throws {
        let r: CGFloat = 0.6, g: CGFloat = 0.2, b: CGFloat = 0.8
        let inputPixel = Pixel(r: r, g: g, b: b)
        let expectedValue = g // g is min

        try assertGrayscaleConversion(
            input: inputPixel.nsColor,
            strategy: .minChannel,
            expected: Pixel(w: expectedValue)
        )
    }
    
    // MARK: - Threshold Accuracy

    @Test("Metal black threshold remaps correctly")
    func testMetalBlackThresholdRemapping() throws {
        let inputPixel = Pixel(w: 0.6)
        let expectedValue = (0.6 - 0.2) / (1.0 - 0.2)
        
        try assertGrayscaleConversion(
            input: inputPixel.nsColor,
            strategy: .average,
            blackThreshold: 0.2,
            whiteThreshold: 1.0,
            expected: Pixel(w: expectedValue)
        )
    }
    
    @Test("Metal combined black and white thresholds remap correctly")
    func testMetalCombinedThresholdRemapping() throws {
        let inputPixel = Pixel(w: 0.5)
        let expectedValue = ((0.5 - 0.2) / (0.8 - 0.2))
        
        try assertGrayscaleConversion(
            input: inputPixel.nsColor,
            strategy: .average,
            blackThreshold: 0.2,
            whiteThreshold: 0.8,
            expected: Pixel(w: expectedValue)
        )
    }

    @Test("Metal value below black threshold returns zero")
    func testMetalValueBelowBlackThreshold() throws {
        let inputPixel = Pixel(w: 0.1)
        
        try assertGrayscaleConversion(
            input: inputPixel.nsColor,
            strategy: .average,
            blackThreshold: 0.2,
            whiteThreshold: 0.8,
            expected: Pixel(w: 0.0)
        )
    }

    @Test("Metal value above white threshold returns one")
    func testMetalValueAboveWhiteThreshold() throws {
        let inputPixel = Pixel(w: 0.9)
        
        try assertGrayscaleConversion(
            input: inputPixel.nsColor,
            strategy: .average,
            blackThreshold: 0.2,
            whiteThreshold: 0.8,
            expected: Pixel(w: 1.0)
        )
    }
    
    // MARK: - Validation

    @Test("Metal engine validation throws for bad thresholds")
    func testMetalEngineValidation() throws {
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
        expected: Pixel
    ) throws {
        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }
        
        let result = try engine
            .withRGBAData(width: 1, height: 1)
            .grayscale(
                strategy: strategy,
                blackThreshold: blackThreshold,
                whiteThreshold: whiteThreshold
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
            "Conversion failed for \(strategy). Expected \(expected), got \(firstPixel)"
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
            UInt8(a * 255)
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
                mipmapLevel: 0
            )
        }
        
        var pixels: [Pixel] = []
        for i in stride(from: 0, to: data.count, by: 4) {
            pixels.append(Pixel(r: data[i], g: data[i+1], b: data[i+2], a: data[i+3]))
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
        a: UInt8 = 255
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
        a: Double = 1.0
    ) {
        self.r = UInt8(r * 255)
        self.g = UInt8(g * 255)
        self.b = UInt8(b * 255)
        self.a = UInt8(a * 255)
    }

    init(
        w: UInt8,
        a: UInt8 = 255
    ) {
        self.r = w
        self.g = w
        self.b = w
        self.a = a
    }

    init(
        w: Double,
        a: Double = 1.0
    ) {
        self.r = UInt8(w * 255)
        self.g = UInt8(w * 255)
        self.b = UInt8(w * 255)
        self.a = UInt8(a * 255)
    }

    /// Checks if two pixels are approximately equal, within a given tolerance.
    func isApproximatelyEqual(to other: Pixel, tolerance: Int = 1) -> Bool {
        return abs(Int(self.r) - Int(other.r)) <= tolerance &&
        abs(Int(self.g) - Int(other.g)) <= tolerance &&
        abs(Int(self.b) - Int(other.b)) <= tolerance &&
        abs(Int(self.a) - Int(other.a)) <= tolerance
    }
}

extension Pixel {
    var nsColor: NSColor {
        return NSColor(
            red: CGFloat(r) / 255.0,
            green: CGFloat(g) / 255.0,
            blue: CGFloat(b) / 255.0,
            alpha: CGFloat(a) / 255.0
        )
    }
}
