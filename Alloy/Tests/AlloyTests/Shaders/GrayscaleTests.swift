//
//  File.swift
//  Alloy
//
//  Created by Bryan Costanza on 6/19/25.
//

import Testing
import AppKit

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

}
