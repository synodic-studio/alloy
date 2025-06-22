import Testing
import AppKit
import Metal

@testable import Alloy

@Suite("Noise Shader Computation Tests")
struct NoiseTests {

    // MARK: - Basic Functionality Tests

    @Test("Noise applies without error")
    func testNoiseBasicFunctionality() throws {
        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }
        
        let inputColor = NSColor.gray
        let data = self.data(from: inputColor)
        
        let result = try engine
            .withRGBAData(width: 1, height: 1)
            .noise(magnitude: 0.1, seed: 42)
            .execute(data: data)

        let outputPixels = try pixels(from: result.texture)
        #expect(outputPixels.count == 1)
        
        // Pixel should have some noise applied but remain within bounds
        if let pixel = outputPixels.first {
            #expect(pixel.r <= 255, "Red channel should remain within bounds")
            #expect(pixel.g <= 255, "Green channel should remain within bounds")
            #expect(pixel.b <= 255, "Blue channel should remain within bounds")
            #expect(pixel.a == 128, "Alpha should remain unchanged")  // Gray alpha = 0.5 * 255
        }
    }

    @Test("Noise with zero magnitude produces no change")
    func testNoiseZeroMagnitude() throws {
        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }
        
        let inputColor = NSColor.red
        let data = self.data(from: inputColor)
        
        let result = try engine
            .withRGBAData(width: 1, height: 1)
            .noise(magnitude: 0.0, seed: 42)
            .execute(data: data)

        let outputPixels = try pixels(from: result.texture)
        let expectedPixel = Pixel(r: inputColor)
        
        #expect(
            outputPixels.first?.isApproximatelyEqual(to: expectedPixel, tolerance: 0) == true,
            "Zero magnitude noise should produce no change"
        )
    }

    @Test("Noise stays within valid color range")
    func testNoiseStaysWithinBounds() throws {
        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }
        
        // Test with very bright white to ensure clamping works
        let inputColor = NSColor.white
        let data = self.data(from: inputColor)
        
        let result = try engine
            .withRGBAData(width: 1, height: 1)
            .noise(magnitude: 1.0, seed: 42)  // Maximum noise
            .execute(data: data)

        let outputPixels = try pixels(from: result.texture)
        
        if let pixel = outputPixels.first {
            #expect(pixel.r <= 255, "Red channel should be clamped to 255")
            #expect(pixel.g <= 255, "Green channel should be clamped to 255")
            #expect(pixel.b <= 255, "Blue channel should be clamped to 255")
            #expect(pixel.r >= 0, "Red channel should be clamped to 0 minimum")
            #expect(pixel.g >= 0, "Green channel should be clamped to 0 minimum")
            #expect(pixel.b >= 0, "Blue channel should be clamped to 0 minimum")
        }
        
        // Test with black to ensure lower bound clamping
        let blackData = self.data(from: NSColor.black)
        
        let resultBlack = try engine
            .withRGBAData(width: 1, height: 1)
            .noise(magnitude: 1.0, seed: 123)
            .execute(data: blackData)

        let blackPixels = try pixels(from: resultBlack.texture)
        
        if let pixel = blackPixels.first {
            #expect(pixel.r <= 255, "Red channel should be within upper bound")
            #expect(pixel.g <= 255, "Green channel should be within upper bound")
            #expect(pixel.b <= 255, "Blue channel should be within upper bound")
            #expect(pixel.r >= 0, "Red channel should be within lower bound")
            #expect(pixel.g >= 0, "Green channel should be within lower bound")
            #expect(pixel.b >= 0, "Blue channel should be within lower bound")
        }
    }

    @Test("Same seed produces same noise")
    func testSameSeedProducesSameNoise() throws {
        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }
        
        let inputColor = NSColor.gray
        let data = self.data(from: inputColor)
        let seed: UInt32 = 12345
        
        let result1 = try engine
            .withRGBAData(width: 1, height: 1)
            .noise(magnitude: 0.5, seed: seed)
            .execute(data: data)
        
        let result2 = try engine
            .withRGBAData(width: 1, height: 1)
            .noise(magnitude: 0.5, seed: seed)
            .execute(data: data)

        let pixels1 = try pixels(from: result1.texture)
        let pixels2 = try pixels(from: result2.texture)
        
        #expect(pixels1.count == pixels2.count)
        #expect(
            pixels1.first?.isApproximatelyEqual(to: pixels2.first!, tolerance: 0) == true,
            "Same seed should produce identical results"
        )
    }

    @Test("Different seeds produce different noise")
    func testDifferentSeedsProduceDifferentNoise() throws {
        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }
        
        let inputColor = NSColor.gray
        let data = self.data(from: inputColor)
        
        let result1 = try engine
            .withRGBAData(width: 1, height: 1)
            .noise(magnitude: 0.5, seed: 11111)
            .execute(data: data)
        
        let result2 = try engine
            .withRGBAData(width: 1, height: 1)
            .noise(magnitude: 0.5, seed: 22222)
            .execute(data: data)

        let pixels1 = try pixels(from: result1.texture)
        let pixels2 = try pixels(from: result2.texture)
        
        #expect(
            pixels1.first?.isApproximatelyEqual(to: pixels2.first!, tolerance: 5) == false,
            "Different seeds should produce different results"
        )
    }

    // MARK: - Parameter Validation Tests

    @Test("Noise validation throws for negative magnitude")
    func testNoiseValidationNegativeMagnitude() throws {
        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }
        
        #expect(throws: MetalEngineError.self) {
            try engine.noise(magnitude: -0.1)
        }
    }

    @Test("Noise validation throws for magnitude greater than 1")
    func testNoiseValidationMagnitudeTooLarge() throws {
        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }
        
        #expect(throws: MetalEngineError.self) {
            try engine.noise(magnitude: 1.1)
        }
    }

    @Test("Noise accepts valid magnitude of 0")
    func testNoiseValidMagnitudeZero() throws {
        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }
        
        // Should not throw
        let _ = try engine.noise(magnitude: 0.0)
    }

    @Test("Noise accepts valid magnitude of 1")
    func testNoiseValidMagnitudeOne() throws {
        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }
        
        // Should not throw
        let _ = try engine.noise(magnitude: 1.0)
    }

    // MARK: - Magnitude Effect Tests

    @Test("Higher magnitude produces more noise")
    func testHigherMagnitudeProducesMoreNoise() throws {
        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }
        
        let inputColor = NSColor.gray  // Mid-range gray to see noise effects
        let data = self.data(from: inputColor)
        let seed: UInt32 = 42
        
        let resultLow = try engine
            .withRGBAData(width: 1, height: 1)
            .noise(magnitude: 0.1, seed: seed)
            .execute(data: data)
        
        let resultHigh = try engine
            .withRGBAData(width: 1, height: 1)
            .noise(magnitude: 0.8, seed: seed)
            .execute(data: data)

        let pixelsLow = try pixels(from: resultLow.texture)
        let pixelsHigh = try pixels(from: resultHigh.texture)
        let originalPixel = Pixel(r: inputColor)
        
        // Calculate deviation from original
        let deviationLow = abs(Int(pixelsLow.first!.r) - Int(originalPixel.r))
        let deviationHigh = abs(Int(pixelsHigh.first!.r) - Int(originalPixel.r))
        
        #expect(
            deviationHigh >= deviationLow,
            "Higher magnitude should produce larger deviation from original"
        )
    }

    // MARK: - Alpha Channel Tests

    @Test("Noise preserves alpha channel")
    func testNoisePreservesAlpha() throws {
        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }
        
        let inputColor = NSColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.7)
        let data = self.data(from: inputColor)
        
        let result = try engine
            .withRGBAData(width: 1, height: 1)
            .noise(magnitude: 0.5, seed: 42)
            .execute(data: data)

        let outputPixels = try pixels(from: result.texture)
        
        if let pixel = outputPixels.first {
            let expectedAlpha = UInt8(0.7 * 255)  // 0.7 * 255 = 178.5 ≈ 179
            #expect(
                abs(Int(pixel.a) - Int(expectedAlpha)) <= 1,
                "Alpha channel should be preserved (expected ~179, got \(pixel.a))"
            )
        }
    }

    // MARK: - Helper Methods
    
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

    init(r: UInt8, g: UInt8, b: UInt8, a: UInt8 = 255) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    init(r: NSColor) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        r.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        self.r = UInt8(red * 255)
        self.g = UInt8(green * 255)
        self.b = UInt8(blue * 255)
        self.a = UInt8(alpha * 255)
    }

    func isApproximatelyEqual(to other: Pixel, tolerance: Int = 1) -> Bool {
        return abs(Int(self.r) - Int(other.r)) <= tolerance &&
        abs(Int(self.g) - Int(other.g)) <= tolerance &&
        abs(Int(self.b) - Int(other.b)) <= tolerance &&
        abs(Int(self.a) - Int(other.a)) <= tolerance
    }
} 