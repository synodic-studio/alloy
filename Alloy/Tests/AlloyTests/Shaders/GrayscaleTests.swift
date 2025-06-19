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
        let r: Double = 0.5, g: Double = 0.8, b: Double = 0.3
        let inputColor = NSColor(red: r, green: g, blue: b, alpha: 1.0)
        
        let weightedSum = (0.299 * r) + (0.587 * g) + (0.114 * b)
        let expectedValue = UInt8(weightedSum * 255)
        let expectedPixel = Pixel(w: expectedValue, a: 255)

        try assertGrayscaleConversion(
            input: inputColor,
            strategy: .weighted,
            expected: expectedPixel
        )
    }

    @Test("Metal average RGB conversion is accurate")
    func testMetalAverageConversion() throws {
        let inputColor = NSColor(red: 0.6, green: 0.9, blue: 0.2, alpha: 1.0)
        let expectedValue = UInt8(((0.6 + 0.9 + 0.2) / 3.0) * 255)
        let expectedPixel = Pixel(w: expectedValue, a: 255)

        try assertGrayscaleConversion(
            input: inputColor,
            strategy: .average,
            expected: expectedPixel
        )
    }

    @Test("Metal red channel conversion is accurate")
    func testMetalRedChannelConversion() throws {
        let r: CGFloat = 0.7, g: CGFloat = 0.4, b: CGFloat = 0.9
        let inputColor = NSColor(red: r, green: g, blue: b, alpha: 1.0)
        let expectedValue = UInt8(r * 255)
        
        try assertGrayscaleConversion(
            input: inputColor,
            strategy: .redChannel,
            expected: Pixel(w: expectedValue, a: 255)
        )
    }
    
    @Test("Metal green channel conversion is accurate")
    func testMetalGreenChannelConversion() throws {
        let r: CGFloat = 0.7, g: CGFloat = 0.4, b: CGFloat = 0.9
        let inputColor = NSColor(red: r, green: g, blue: b, alpha: 1.0)
        let expectedValue = UInt8(g * 255)
        
        try assertGrayscaleConversion(
            input: inputColor,
            strategy: .greenChannel,
            expected: Pixel(w: expectedValue, a: 255)
        )
    }
    
    @Test("Metal blue channel conversion is accurate")
    func testMetalBlueChannelConversion() throws {
        let r: CGFloat = 0.7, g: CGFloat = 0.4, b: CGFloat = 0.9
        let inputColor = NSColor(red: r, green: g, blue: b, alpha: 1.0)
        let expectedValue = UInt8(b * 255)
        
        try assertGrayscaleConversion(
            input: inputColor,
            strategy: .blueChannel,
            expected: Pixel(w: expectedValue, a: 255)
        )
    }

    @Test("Metal max channel conversion is accurate")
    func testMetalMaxChannelConversion() throws {
        let r: CGFloat = 0.6, g: CGFloat = 0.2, b: CGFloat = 0.8
        let inputColor = NSColor(red: r, green: g, blue: b, alpha: 1.0)
        let expectedValue = UInt8(b * 255) // b is max

        try assertGrayscaleConversion(
            input: inputColor,
            strategy: .maxChannel,
            expected: Pixel(w: expectedValue, a: 255)
        )
    }
    
    @Test("Metal min channel conversion is accurate")
    func testMetalMinChannelConversion() throws {
        let r: CGFloat = 0.6, g: CGFloat = 0.2, b: CGFloat = 0.8
        let inputColor = NSColor(red: r, green: g, blue: b, alpha: 1.0)
        let expectedValue = UInt8(g * 255) // g is min

        try assertGrayscaleConversion(
            input: inputColor,
            strategy: .minChannel,
            expected: Pixel(w: expectedValue, a: 255)
        )
    }
    
    // MARK: - Threshold Accuracy

    @Test("Metal black threshold remaps correctly")
    func testMetalBlackThresholdRemapping() throws {
        let inputColor = NSColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1.0)
        let expectedValue = UInt8(((0.6 - 0.2) / (1.0 - 0.2)) * 255)
        
        try assertGrayscaleConversion(
            input: inputColor,
            strategy: .average,
            blackThreshold: 0.2,
            whiteThreshold: 1.0,
            expected: Pixel(w: expectedValue, a: 255)
        )
    }
    
    @Test("Metal combined black and white thresholds remap correctly")
    func testMetalCombinedThresholdRemapping() throws {
        let inputColor = NSColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        let expectedValue = UInt8(((0.5 - 0.2) / (0.8 - 0.2)) * 255)
        
        try assertGrayscaleConversion(
            input: inputColor,
            strategy: .average,
            blackThreshold: 0.2,
            whiteThreshold: 0.8,
            expected: Pixel(w: expectedValue, a: 255)
        )
    }

    @Test("Metal value below black threshold returns zero")
    func testMetalValueBelowBlackThreshold() throws {
        let inputColor = NSColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        
        try assertGrayscaleConversion(
            input: inputColor,
            strategy: .average,
            blackThreshold: 0.2,
            whiteThreshold: 0.8,
            expected: Pixel(r: 0, g: 0, b: 0, a: 255)
        )
    }

    @Test("Metal value above white threshold returns one")
    func testMetalValueAboveWhiteThreshold() throws {
        let inputColor = NSColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0)
        
        try assertGrayscaleConversion(
            input: inputColor,
            strategy: .average,
            blackThreshold: 0.2,
            whiteThreshold: 0.8,
            expected: Pixel(r: 255, g: 255, b: 255, a: 255)
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

        #expect(firstPixel.isApproximatelyEqual(to: expected, tolerance: 1),
               "Conversion failed for \(strategy). Expected \(expected), got \(firstPixel)")
    }
    
    /// Represents an RGBA pixel for testing purposes.

    
    /// Creates a 1x1 image Data object from a single NSColor.
    private func data(from color: NSColor) -> Data {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        
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
        w: UInt8,
        a: UInt8 = 255
    ) {
        self.r = w
        self.g = w
        self.b = w
        self.a = a
    }

    /// Checks if two pixels are approximately equal, within a given tolerance.
    func isApproximatelyEqual(to other: Pixel, tolerance: Int = 1) -> Bool {
        return abs(Int(self.r) - Int(other.r)) <= tolerance &&
        abs(Int(self.g) - Int(other.g)) <= tolerance &&
        abs(Int(self.b) - Int(other.b)) <= tolerance &&
        abs(Int(self.a) - Int(other.a)) <= tolerance
    }
}
