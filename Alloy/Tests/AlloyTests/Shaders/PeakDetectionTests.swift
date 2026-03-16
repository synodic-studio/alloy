import AppKit
import Metal
import Testing

@testable import Alloy

@Suite("Peak Detection Shader Computation Tests")
struct PeakDetectionTests {
    // MARK: - Basic Functionality Tests

    @Test("Peak detection executes without error")
    func peakDetectionBasicFunctionality() throws {
        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }

        let data = createTestImageWithSinglePeak()

        let result = try engine
            .withRGBAData(width: 5, height: 5)
            .executeWithPeakDetection(
                data: data,
                neighborhoodSize: 3,
                minDistance: 1.0,
                maxPeaks: 10,
                threshold: 0.5,
            )

        #expect(result.width == 5)
        #expect(result.height == 5)
        #expect(result.detectedPeaks.count <= 10)
    }

    @Test("Peak detection finds obvious peak")
    func peakDetectionFindsObviousPeak() throws {
        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }

        let data = createTestImageWithSinglePeak()

        let result = try engine
            .withRGBAData(width: 5, height: 5)
            .executeWithPeakDetection(
                data: data,
                neighborhoodSize: 3,
                minDistance: 1.0,
                maxPeaks: 10,
                threshold: 0.5,
            )

        #expect(result.detectedPeaks.count >= 1, "Should detect the central bright peak")

        if let peak = result.detectedPeaks.first {
            #expect(peak.x >= 1.0 && peak.x <= 3.0, "Peak should be near center horizontally")
            #expect(peak.y >= 1.0 && peak.y <= 3.0, "Peak should be near center vertically")
            #expect(peak.value > 128, "Peak value should be above threshold, in 0-255 range")
        }
    }

    @Test("Peak detection with high threshold filters low peaks")
    func peakDetectionHighThresholdFilters() throws {
        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }

        let data = createTestImageWithMultiplePeaks()

        // Test with low threshold
        let resultLowThreshold = try engine
            .withRGBAData(width: 7, height: 7)
            .executeWithPeakDetection(
                data: data,
                neighborhoodSize: 3,
                minDistance: 1.0,
                maxPeaks: 50,
                threshold: 0.3,
            )

        // Test with high threshold
        let resultHighThreshold = try engine
            .withRGBAData(width: 7, height: 7)
            .executeWithPeakDetection(
                data: data,
                neighborhoodSize: 3,
                minDistance: 1.0,
                maxPeaks: 50,
                threshold: 0.8,
            )

        #expect(
            resultHighThreshold.detectedPeaks.count <= resultLowThreshold.detectedPeaks.count,
            "Higher threshold should detect fewer or equal peaks",
        )
    }

    @Test("Peak detection respects max peaks limit")
    func peakDetectionRespectsMaxPeaks() throws {
        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }

        let data = createTestImageWithMultiplePeaks()
        let maxPeaks = 3

        let result = try engine
            .withRGBAData(width: 7, height: 7)
            .executeWithPeakDetection(
                data: data,
                neighborhoodSize: 3,
                minDistance: 1.0,
                maxPeaks: maxPeaks,
                threshold: 0.3,
            )

        #expect(
            result.detectedPeaks.count <= maxPeaks,
            "Should not exceed max peaks limit",
        )
    }

    @Test("Peak detection respects minimum distance")
    func peakDetectionRespectsMinDistance() throws {
        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }

        let data = createTestImageWithClosePeaks()
        let minDistance = 5.0

        let result = try engine
            .withRGBAData(width: 9, height: 9)
            .executeWithPeakDetection(
                data: data,
                neighborhoodSize: 3,
                minDistance: minDistance,
                maxPeaks: 10,
                threshold: 0.5,
            )

        // Check that no two peaks are closer than minDistance
        for i in 0 ..< result.detectedPeaks.count {
            for j in (i + 1) ..< result.detectedPeaks.count {
                let peak1 = result.detectedPeaks[i]
                let peak2 = result.detectedPeaks[j]

                let distance = sqrt(pow(peak1.x - peak2.x, 2) + pow(peak1.y - peak2.y, 2))

                #expect(
                    distance >= Float(minDistance) - 0.1, // Small tolerance for floating point
                    "Peaks should be at least \(minDistance) apart, but found distance \(distance)",
                )
            }
        }
    }

    // MARK: - Neighborhood Size Tests

    @Test("Different neighborhood sizes affect detection")
    func differentNeighborhoodSizes() throws {
        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }

        let data = createTestImageWithBorderPeak()

        // 3x3 neighborhood detection
        let result3x3 = try engine
            .withRGBAData(width: 5, height: 5)
            .executeWithPeakDetection(
                data: data,
                neighborhoodSize: 3,
                minDistance: 1.0,
                maxPeaks: 10,
                threshold: 0.5,
            )

        // 5x5 neighborhood detection (should be more restrictive)
        let result5x5 = try engine
            .withRGBAData(width: 5, height: 5)
            .executeWithPeakDetection(
                data: data,
                neighborhoodSize: 5,
                minDistance: 1.0,
                maxPeaks: 10,
                threshold: 0.5,
            )

        // A larger neighborhood is more restrictive, so it should find fewer or equal peaks
        #expect(
            result5x5.detectedPeaks.count <= result3x3.detectedPeaks.count,
            "5x5 neighborhood should be more restrictive than 3x3",
        )
    }

    // MARK: - Parameter Validation Tests

    @Test("Peak detection validation throws for invalid neighborhood size")
    func peakDetectionValidationInvalidNeighborhoodSize() throws {
        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }

        let data = createTestImageWithSinglePeak()

        // Test with an even number
        #expect(throws: MetalEngineError.self) {
            try engine
                .withRGBAData(width: 5, height: 5)
                .executeWithPeakDetection(
                    data: data,
                    neighborhoodSize: 4, // Invalid - must be odd
                    minDistance: 1.0,
                    maxPeaks: 10,
                    threshold: 0.5,
                )
        }

        // Test with a number less than 3
        #expect(throws: MetalEngineError.self) {
            try engine
                .withRGBAData(width: 5, height: 5)
                .executeWithPeakDetection(
                    data: data,
                    neighborhoodSize: 1, // Invalid - must be >= 3
                    minDistance: 1.0,
                    maxPeaks: 10,
                    threshold: 0.5,
                )
        }
    }

    @Test("Peak detection validation throws for negative min distance")
    func peakDetectionValidationNegativeMinDistance() throws {
        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }

        let data = createTestImageWithSinglePeak()

        #expect(throws: MetalEngineError.self) {
            try engine
                .withRGBAData(width: 5, height: 5)
                .executeWithPeakDetection(
                    data: data,
                    neighborhoodSize: 3,
                    minDistance: -1.0,
                    maxPeaks: 10,
                    threshold: 0.5,
                )
        }
    }

    @Test("Peak detection validation throws for invalid threshold")
    func peakDetectionValidationInvalidThreshold() throws {
        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }

        let data = createTestImageWithSinglePeak()

        #expect(throws: MetalEngineError.self) {
            try engine
                .withRGBAData(width: 5, height: 5)
                .executeWithPeakDetection(
                    data: data,
                    neighborhoodSize: 3,
                    minDistance: 1.0,
                    maxPeaks: 10,
                    threshold: 1.5, // Invalid - must be 0.0-1.0
                )
        }
    }

    @Test("Peak detection validation throws for zero max peaks")
    func peakDetectionValidationZeroMaxPeaks() throws {
        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }

        let data = createTestImageWithSinglePeak()

        #expect(throws: MetalEngineError.self) {
            try engine
                .withRGBAData(width: 5, height: 5)
                .executeWithPeakDetection(
                    data: data,
                    neighborhoodSize: 3,
                    minDistance: 1.0,
                    maxPeaks: 0,
                    threshold: 0.5,
                )
        }
    }

    // MARK: - Helper Methods

    /// Creates a 5x5 test image with a single bright peak in the center
    private func createTestImageWithSinglePeak() -> Data {
        var data = Data()

        for y in 0 ..< 5 {
            for x in 0 ..< 5 {
                if x == 2, y == 2 {
                    // Bright center peak
                    data.append(contentsOf: [255, 255, 255, 255])
                } else {
                    // Dark background
                    data.append(contentsOf: [50, 50, 50, 255])
                }
            }
        }

        return data
    }

    /// Creates a 7x7 test image with multiple peaks of varying brightness
    private func createTestImageWithMultiplePeaks() -> Data {
        var data = Data()

        for y in 0 ..< 7 {
            for x in 0 ..< 7 {
                var brightness: UInt8 = 30 // Dark background

                // Peak 1: Center, very bright
                if x == 3, y == 3 {
                    brightness = 255
                }
                // Peak 2: Top-left, medium bright
                else if x == 1, y == 1 {
                    brightness = 200
                }
                // Peak 3: Bottom-right, medium bright
                else if x == 5, y == 5 {
                    brightness = 180
                }
                // Peak 4: Top-right, dim (below some thresholds)
                else if x == 5, y == 1 {
                    brightness = 120
                }

                data.append(contentsOf: [brightness, brightness, brightness, 255])
            }
        }

        return data
    }

    /// Creates a 9x9 test image with two peaks close together
    private func createTestImageWithClosePeaks() -> Data {
        var data = Data()

        for y in 0 ..< 9 {
            for x in 0 ..< 9 {
                var brightness: UInt8 = 40 // Dark background

                // Peak 1
                if x == 3, y == 4 {
                    brightness = 255
                }
                // Peak 2 - close to Peak 1
                else if x == 5, y == 4 {
                    brightness = 240
                }
                // Peak 3 - far from others
                else if x == 1, y == 1 {
                    brightness = 220
                }

                data.append(contentsOf: [brightness, brightness, brightness, 255])
            }
        }

        return data
    }

    /// Creates a 5x5 test image with peak near border to test neighborhood edge cases
    private func createTestImageWithBorderPeak() -> Data {
        var data = Data()

        for y in 0 ..< 5 {
            for x in 0 ..< 5 {
                var brightness: UInt8 = 30 // Dark background

                // Peak near border
                if x == 0, y == 2 {
                    brightness = 255
                }
                // Another peak in center
                else if x == 3, y == 2 {
                    brightness = 200
                }

                data.append(contentsOf: [brightness, brightness, brightness, 255])
            }
        }

        return data
    }

    enum TestError: Error {
        case engineInitializationFailed
    }
}
