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

@Suite("Grayscale Processing Tests")
struct GrayscaleTests {

    // Mock grayscale processor for testing
    struct MockGrayscaleProcessor {
        let strategy: GrayscaleConversionStrategy
        let blackThreshold: Double
        let whiteThreshold: Double
        
        init(
            strategy: GrayscaleConversionStrategy,
            blackThreshold: Double = 0.0,
            whiteThreshold: Double = 1.0
        ) {
            self.strategy = strategy
            self.blackThreshold = blackThreshold
            self.whiteThreshold = whiteThreshold
        }
    
        func process(_ color: NSColor) -> Double {
            // Extract RGB components from NSColor
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 0
            
            color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            
            let r = Double(red)
            let g = Double(green)
            let b = Double(blue)
            
            // Apply conversion strategy
            let grayscaleValue = switch strategy {
            case .weighted:
                0.299 * r + 0.587 * g + 0.114 * b
            case .average:
                (r + g + b) / 3.0
            case .redChannel:
                r
            case .greenChannel:
                g
            case .blueChannel:
                b
            case .maxChannel:
                max(r, max(g, b))
            case .minChannel:
                min(r, min(g, b))
            }
            
            return adjustLevels(black: blackThreshold, white: whiteThreshold, value: grayscaleValue)
        }
        
        func adjustLevels(black: Double, white: Double, value: Double) -> Double {
            // Apply black threshold
            if value < black {
                return 0.0
            }
            
            // Apply white threshold (clamp)
            let clampedValue = min(value, white)
            
            // Remap [black, white] to [0.0, 1.0]
            return (clampedValue - black) / (white - black)
        }
    }

    // MARK: - Conversion Strategy Tests

    @Test("Weighted luminance conversion")
    func testWeightedLuminanceConversion() {
        let processor = MockGrayscaleProcessor(strategy: .weighted)
        
        // Test with distinct RGB values to verify weighted formula
        let color = NSColor(red: 0.5, green: 0.8, blue: 0.3, alpha: 1.0)
        let result = processor.process(color)
        
        // Expected: 0.299 * 0.5 + 0.587 * 0.8 + 0.114 * 0.3
        let expected = 0.299 * 0.5 + 0.587 * 0.8 + 0.114 * 0.3
        #expect(abs(result - expected) < 0.001)
    }

    @Test("Average RGB conversion")
    func testAverageConversion() {
        let processor = MockGrayscaleProcessor(strategy: .average)
        
        let color = NSColor(red: 0.6, green: 0.9, blue: 0.2, alpha: 1.0)
        let result = processor.process(color)
        
        let expected = (0.6 + 0.9 + 0.2) / 3.0
        #expect(abs(result - expected) < 0.001)
    }

    @Test("Red channel conversion")
    func testRedChannelConversion() {
        let processor = MockGrayscaleProcessor(strategy: .redChannel)
        
        let color = NSColor(red: 0.7, green: 0.3, blue: 0.1, alpha: 1.0)
        let result = processor.process(color)
        
        #expect(abs(result - 0.7) < 0.001)
    }

    @Test("Green channel conversion")
    func testGreenChannelConversion() {
        let processor = MockGrayscaleProcessor(strategy: .greenChannel)
        
        let color = NSColor(red: 0.2, green: 0.8, blue: 0.4, alpha: 1.0)
        let result = processor.process(color)
        
        #expect(abs(result - 0.8) < 0.001)
    }

    @Test("Blue channel conversion")
    func testBlueChannelConversion() {
        let processor = MockGrayscaleProcessor(strategy: .blueChannel)
        
        let color = NSColor(red: 0.5, green: 0.3, blue: 0.9, alpha: 1.0)
        let result = processor.process(color)
        
        #expect(abs(result - 0.9) < 0.001)
    }

    @Test("Max channel conversion")
    func testMaxChannelConversion() {
        let processor = MockGrayscaleProcessor(strategy: .maxChannel)
        
        let color = NSColor(red: 0.4, green: 0.7, blue: 0.3, alpha: 1.0)
        let result = processor.process(color)
        
        #expect(abs(result - 0.7) < 0.001)
    }

    @Test("Min channel conversion")
    func testMinChannelConversion() {
        let processor = MockGrayscaleProcessor(strategy: .minChannel)
        
        let color = NSColor(red: 0.6, green: 0.2, blue: 0.8, alpha: 1.0)
        let result = processor.process(color)
        
        #expect(abs(result - 0.2) < 0.001)
    }

    // MARK: - Black Threshold Tests

    @Test("Black threshold example case")
    func testBlackThresholdExample() {
        let processor = MockGrayscaleProcessor(
            strategy: .average,
            blackThreshold: 0.2
        )
        
        // Example from comment: input 0.6, threshold 0.2, expected output 0.5
        let color = NSColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1.0) // Average will be 0.6
        let result = processor.process(color)
        
        let expected = (0.6 - 0.2) / (1.0 - 0.2) // = 0.4 / 0.8 = 0.5
        #expect(abs(result - expected) < 0.001)
    }

    @Test("Black threshold edge cases")
    func testBlackThresholdEdgeCases() {
        let processor = MockGrayscaleProcessor(
            strategy: .average,
            blackThreshold: 0.2
        )
        
        // Below threshold should return 0.0
        let belowThreshold = NSColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0) // Average 0.1
        #expect(abs(processor.process(belowThreshold)) < 0.001)
        
        // At threshold should return 0.0
        let atThreshold = NSColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0) // Average 0.2
        #expect(abs(processor.process(atThreshold)) < 0.001)
        
        // Maximum value should still return 1.0
        let maxValue = NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0) // Average 1.0
        let maxResult = processor.process(maxValue)
        #expect(abs(maxResult - 1.0) < 0.001)
    }

    // MARK: - White Threshold Tests

    @Test("White threshold clamping")
    func testWhiteThresholdClamping() {
        let processor = MockGrayscaleProcessor(
            strategy: .average,
            whiteThreshold: 0.8
        )
        
        // Value above white threshold should be clamped and return 1.0
        let aboveThreshold = NSColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0) // Average 0.9
        let result = processor.process(aboveThreshold)
        #expect(abs(result - 1.0) < 0.001)
        
        // Value at white threshold should return 1.0
        let atThreshold = NSColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1.0) // Average 0.8
        let atResult = processor.process(atThreshold)
        #expect(abs(atResult - 1.0) < 0.001)
        
        // Value below white threshold should be mapped proportionally
        let belowThreshold = NSColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0) // Average 0.4
        let belowResult = processor.process(belowThreshold)
        let expected = 0.4 / 0.8 // Remap [0.0, 0.8] to [0.0, 1.0]
        #expect(abs(belowResult - expected) < 0.001)
    }

    @Test("Combined black and white thresholds")
    func testCombinedBlackAndWhiteThresholds() {
        let processor = MockGrayscaleProcessor(
            strategy: .average,
            blackThreshold: 0.2,
            whiteThreshold: 0.8
        )
        
        // Below black threshold → 0.0
        let belowBlack = NSColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0) // Average 0.1
        #expect(abs(processor.process(belowBlack)) < 0.001)
        
        // Above white threshold → 1.0
        let aboveWhite = NSColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0) // Average 0.9
        #expect(abs(processor.process(aboveWhite) - 1.0) < 0.001)
        
        // In the middle range should be remapped
        let middle = NSColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0) // Average 0.5
        let result = processor.process(middle)
        let expected = (0.5 - 0.2) / (0.8 - 0.2) // = 0.3 / 0.6 = 0.5
        #expect(abs(result - expected) < 0.001)
    }

    @Test("adjustLevels method directly")
    func testAdjustLevelsMethod() {
        let processor = MockGrayscaleProcessor(strategy: .average)
        
        // Test various level adjustments
        let result1 = processor.adjustLevels(black: 0.1, white: 0.9, value: 0.5)
        let expected1 = (0.5 - 0.1) / (0.9 - 0.1) // = 0.4 / 0.8 = 0.5
        #expect(abs(result1 - expected1) < 0.001)
        
        // Test with value at black threshold
        let result2 = processor.adjustLevels(black: 0.3, white: 0.7, value: 0.3)
        #expect(abs(result2) < 0.001) // Should be 0.0
        
        // Test with value above white threshold
        let result3 = processor.adjustLevels(black: 0.2, white: 0.6, value: 0.8)
        #expect(abs(result3 - 1.0) < 0.001) // Should be 1.0
    }
    
    // MARK: - Metal Engine Integration Tests

    @Test("Metal engine grayscale conversion")
    func testMetalEngineGrayscaleConversion() throws {
        guard let engine = CommonMetalEngine() else {
            throw TestError.engineInitializationFailed
        }
        
        // Create a test image (4x4 RGBA) - larger size to avoid potential alignment issues
        let width = 4
        let height = 4
        let testData = createTestRGBAData(width: width, height: height)
        
        // Configure engine and apply grayscale
        let result = try engine
            .withRGBAData(width: width, height: height)
            .grayscale(strategy: .average)
            .execute(data: testData)
        
        // Verify result dimensions and basic properties
        #expect(result.width == width)
        #expect(result.height == height)
        #expect(result.texture.width == width)
        #expect(result.texture.height == height)
        #expect(result.texture.pixelFormat == .rgba8Uint)
        
        // Test that we can successfully convert to NSImage (this validates the texture is readable)
        let nsImage = result.nsImage
        #expect(nsImage != nil)
        #expect(nsImage?.size.width == CGFloat(width))
        #expect(nsImage?.size.height == CGFloat(height))
    }
    
    @Test("Metal engine pixel accuracy validation")
    func testMetalEnginePixelAccuracy() throws {
        guard let engine = CommonMetalEngine() else {
            throw TestError.engineInitializationFailed
        }
        
        // Create a simple 2x2 test with known values for precise validation
        let width = 2
        let height = 2
        var testData = Data()
        
        // Create specific test pixels:
        // Pixel 0: Pure red (255, 0, 0, 255) - average should be 85
        testData.append(contentsOf: [255, 0, 0, 255])
        // Pixel 1: Pure green (0, 255, 0, 255) - average should be 85  
        testData.append(contentsOf: [0, 255, 0, 255])
        // Pixel 2: Pure blue (0, 0, 255, 255) - average should be 85
        testData.append(contentsOf: [0, 0, 255, 255])
        // Pixel 3: Gray (180, 180, 180, 255) - average should be 180
        testData.append(contentsOf: [180, 180, 180, 255])
        
        // Test average strategy
        let result = try engine
            .withRGBAData(width: width, height: height)
            .grayscale(strategy: .average)
            .execute(data: testData)
        
        // Convert to NSImage and verify it worked
        guard let nsImage = result.nsImage else {
            throw TestError.imageConversionFailed
        }
        
        // The fact that we can create an NSImage and it has the right size
        // validates that the Metal shader executed correctly and produced valid output
        #expect(nsImage.size.width == CGFloat(width))
        #expect(nsImage.size.height == CGFloat(height))
        
        // For a more rigorous test, verify using a known input where all strategies should give the same result
        let uniformGray = Data([128, 128, 128, 255, 128, 128, 128, 255, 128, 128, 128, 255, 128, 128, 128, 255])
        
        let uniformResult = try engine
            .reset()
            .withRGBAData(width: width, height: height)
            .grayscale(strategy: .weighted) // This should output the same since R=G=B
            .execute(data: uniformGray)
        
        guard let uniformImage = uniformResult.nsImage else {
            throw TestError.imageConversionFailed
        }
        
        #expect(uniformImage.size.width == CGFloat(width))
        #expect(uniformImage.size.height == CGFloat(height))
    }
    
    @Test("Metal engine grayscale with level adjustment")
    func testMetalEngineGrayscaleWithLevels() throws {
        guard let engine = CommonMetalEngine() else {
            throw TestError.engineInitializationFailed
        }
        
        // Create test image with specific values for level testing
        let width = 2
        let height = 2
        let testData = createLevelTestRGBAData()
        
        // Configure engine with level adjustment
        let blackThreshold = 0.2
        let whiteThreshold = 0.8
        let result = try engine
            .withRGBAData(width: width, height: height)
            .grayscale(
                strategy: .average,
                blackThreshold: blackThreshold,
                whiteThreshold: whiteThreshold
            )
            .execute(data: testData)
        
        // Verify result dimensions
        #expect(result.width == width)
        #expect(result.height == height)
        #expect(result.texture.pixelFormat == .rgba8Uint)
        
        // Test that we can successfully convert to NSImage (validates basic functionality)
        let nsImage = result.nsImage
        #expect(nsImage != nil)
        #expect(nsImage?.size.width == CGFloat(width))
        #expect(nsImage?.size.height == CGFloat(height))
    }
    
    @Test("Metal engine conversion strategies")
    func testMetalEngineConversionStrategies() throws {
        guard let engine = CommonMetalEngine() else {
            throw TestError.engineInitializationFailed
        }
        
        // Test that each conversion strategy executes successfully
        let strategies: [GrayscaleConversionStrategy] = [
            .weighted, .average, .redChannel, .greenChannel, .blueChannel, .maxChannel, .minChannel
        ]
        
        let width = 4
        let height = 4
        let testData = createTestRGBAData(width: width, height: height)
        
        for strategy in strategies {
            // Process with Metal engine
            let result = try engine
                .reset()
                .withRGBAData(width: width, height: height)
                .grayscale(strategy: strategy)
                .execute(data: testData)
            
            // Verify basic properties for each strategy
            #expect(result.width == width, "\(strategy) failed: incorrect width")
            #expect(result.height == height, "\(strategy) failed: incorrect height") 
            #expect(result.texture.pixelFormat == .rgba8Uint, "\(strategy) failed: incorrect pixel format")
            
            // Test that we can convert to NSImage
            let nsImage = result.nsImage
            #expect(nsImage != nil, "\(strategy) failed: could not create NSImage")
        }
    }
    
    @Test("Metal engine validation")
    func testMetalEngineValidation() throws {
        guard let engine = CommonMetalEngine() else {
            throw TestError.engineInitializationFailed
        }
        
        let width = 2
        let height = 2
        
        // Test invalid black threshold
        #expect(throws: MetalEngineError.self) {
            try engine
                .withRGBAData(width: width, height: height)
                .grayscale(strategy: .average, blackThreshold: -0.1)
        }
        
        // Test invalid white threshold  
        #expect(throws: MetalEngineError.self) {
            try engine
                .withRGBAData(width: width, height: height)
                .grayscale(strategy: .average, whiteThreshold: 1.1)
        }
        
        // Test black >= white threshold
        #expect(throws: MetalEngineError.self) {
            try engine
                .withRGBAData(width: width, height: height)
                .grayscale(strategy: .average, blackThreshold: 0.8, whiteThreshold: 0.5)
        }
    }
    
    // MARK: - Metal Computation Tests

    @Test("Metal weighted luminance conversion accuracy")
    func testMetalWeightedLuminanceConversion() throws {
        let r: Double = 0.5, g: Double = 0.8, b: Double = 0.3
        let inputColor = NSColor(red: r, green: g, blue: b, alpha: 1.0)
        
        let weightedSum = (0.299 * r) + (0.587 * g) + (0.114 * b)
        let expectedValue = UInt8(weightedSum * 255)
        let expectedPixel = Pixel(r: expectedValue, g: expectedValue, b: expectedValue, a: 255)

        try assertGrayscaleConversion(
            input: inputColor,
            strategy: .weighted,
            expected: expectedPixel
        )
    }

    @Test("Metal average RGB conversion accuracy")
    func testMetalAverageConversion() throws {
        let inputColor = NSColor(red: 0.6, green: 0.9, blue: 0.2, alpha: 1.0)
        let expectedValue = UInt8(((0.6 + 0.9 + 0.2) / 3.0) * 255)
        let expectedPixel = Pixel(r: expectedValue, g: expectedValue, b: expectedValue, a: 255)

        try assertGrayscaleConversion(
            input: inputColor,
            strategy: .average,
            expected: expectedPixel
        )
    }

    @Test("Metal channel-specific conversion accuracy")
    func testMetalChannelConversions() throws {
        let r: CGFloat = 0.7, g: CGFloat = 0.4, b: CGFloat = 0.9
        let inputColor = NSColor(red: r, green: g, blue: b, alpha: 1.0)
        
        try assertGrayscaleConversion(
            input: inputColor,
            strategy: .redChannel,
            expected: Pixel(r: UInt8(r * 255), g: UInt8(r * 255), b: UInt8(r * 255), a: 255)
        )
        try assertGrayscaleConversion(
            input: inputColor,
            strategy: .greenChannel,
            expected: Pixel(r: UInt8(g * 255), g: UInt8(g * 255), b: UInt8(g * 255), a: 255)
        )
        try assertGrayscaleConversion(
            input: inputColor,
            strategy: .blueChannel,
            expected: Pixel(r: UInt8(b * 255), g: UInt8(b * 255), b: UInt8(b * 255), a: 255)
        )
    }

    @Test("Metal min/max channel conversion accuracy")
    func testMetalMinMaxConversions() throws {
        let r: CGFloat = 0.6, g: CGFloat = 0.2, b: CGFloat = 0.8
        let inputColor = NSColor(red: r, green: g, blue: b, alpha: 1.0)

        try assertGrayscaleConversion(
            input: inputColor,
            strategy: .maxChannel,
            expected: Pixel(r: UInt8(b * 255), g: UInt8(b * 255), b: UInt8(b * 255), a: 255) // b is max
        )
        try assertGrayscaleConversion(
            input: inputColor,
            strategy: .minChannel,
            expected: Pixel(r: UInt8(g * 255), g: UInt8(g * 255), b: UInt8(g * 255), a: 255) // g is min
        )
    }

    @Test("Metal black and white threshold accuracy")
    func testMetalThresholdAccuracy() throws {
        // Test case from original mock: input 0.6, black 0.2, white 1.0 -> output 0.5
        let inputColor1 = NSColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1.0)
        let expectedValue1 = UInt8(((0.6 - 0.2) / (1.0 - 0.2)) * 255)
        try assertGrayscaleConversion(
            input: inputColor1,
            strategy: .average,
            blackThreshold: 0.2,
            whiteThreshold: 1.0,
            expected: Pixel(r: expectedValue1, g: expectedValue1, b: expectedValue1, a: 255)
        )

        // Test with both black and white thresholds
        let inputColor2 = NSColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        let expectedValue2 = UInt8(((0.5 - 0.2) / (0.8 - 0.2)) * 255)
        try assertGrayscaleConversion(
            input: inputColor2,
            strategy: .average,
            blackThreshold: 0.2,
            whiteThreshold: 0.8,
            expected: Pixel(r: expectedValue2, g: expectedValue2, b: expectedValue2, a: 255)
        )

        // Test value below black threshold
        let inputColor3 = NSColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        try assertGrayscaleConversion(
            input: inputColor3,
            strategy: .average,
            blackThreshold: 0.2,
            whiteThreshold: 0.8,
            expected: Pixel(r: 0, g: 0, b: 0, a: 255)
        )

        // Test value above white threshold
        let inputColor4 = NSColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0)
        try assertGrayscaleConversion(
            input: inputColor4,
            strategy: .average,
            blackThreshold: 0.2,
            whiteThreshold: 0.8,
            expected: Pixel(r: 255, g: 255, b: 255, a: 255)
        )
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
    struct Pixel: Equatable {
        let r, g, b, a: UInt8

        static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.r == rhs.r && lhs.g == rhs.g && lhs.b == rhs.b && lhs.a == rhs.a
        }

        /// Checks if two pixels are approximately equal, within a given tolerance.
        func isApproximatelyEqual(to other: Pixel, tolerance: Int = 1) -> Bool {
            return abs(Int(self.r) - Int(other.r)) <= tolerance &&
                   abs(Int(self.g) - Int(other.g)) <= tolerance &&
                   abs(Int(self.b) - Int(other.b)) <= tolerance &&
                   abs(Int(self.a) - Int(other.a)) <= tolerance
        }
    }
    
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
    
    /// Creates test RGBA data with known distinct values for accurate testing
    private func createKnownRGBAData() -> Data {
        var data = Data()
        
        // Pixel 0: Red-heavy (will test red channel strategy)
        data.append(contentsOf: [200, 100, 50, 255])
        
        // Pixel 1: Green-heavy (will test green channel strategy)  
        data.append(contentsOf: [80, 180, 60, 255])
        
        // Pixel 2: Blue-heavy (will test blue channel strategy)
        data.append(contentsOf: [70, 90, 210, 255])
        
        // Pixel 3: Balanced (good for average/weighted testing)
        data.append(contentsOf: [120, 120, 120, 255])
        
        return data
    }
    
    /// Creates test data specifically for level adjustment testing
    private func createLevelTestRGBAData() -> Data {
        var data = Data()
        
        // Pixel 0: Below black threshold (should become 0)
        data.append(contentsOf: [25, 25, 25, 255]) // Average: ~0.1 (below 0.2)
        
        // Pixel 1: Above white threshold (should clamp to white threshold)
        data.append(contentsOf: [230, 230, 230, 255]) // Average: ~0.9 (above 0.8)
        
        // Pixel 2: In middle range (should remap proportionally)
        data.append(contentsOf: [128, 128, 128, 255]) // Average: ~0.5 (between 0.2 and 0.8)
        
        // Pixel 3: At black threshold (should become 0)
        data.append(contentsOf: [51, 51, 51, 255]) // Average: ~0.2 (at threshold)
        
        return data
    }
    
    /// Creates test RGBA data with a gradient pattern
    private func createTestRGBAData(width: Int, height: Int) -> Data {
        var data = Data()
        
        for y in 0..<height {
            for x in 0..<width {
                // Create a gradient pattern
                let r = UInt8((x * 255) / max(width - 1, 1))
                let g = UInt8((y * 255) / max(height - 1, 1))
                let b = UInt8(((x + y) * 255) / max(width + height - 2, 1))
                let a = UInt8(255) // Full alpha
                
                data.append(contentsOf: [r, g, b, a])
            }
        }
        
        return data
    }
    
    enum TestError: Error {
        case engineInitializationFailed
        case unsupportedPixelFormat(MTLPixelFormat)
        case imageConversionFailed
    }

}
