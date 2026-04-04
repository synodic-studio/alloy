import Foundation
import Testing

@testable import Alloy

@Suite("Invert Shader Tests")
struct InvertTests {
    @Test("Image Invert Operation")
    func invertOperation() throws {
        guard let engine = CommonMetalEngine() else {
            throw MetalEngineError.generalError(message: "Failed to create Metal engine")
        }

        let size = 256
        let testData = createMockImageData(width: size, height: size)

        // Configure pipeline with invert
        let configuredEngine = try engine
            .withRawData(width: size, height: size)
            .invert()

        // Execute with test data
        let result = try configuredEngine.execute(data: testData)

        #expect(result.width == size)
        #expect(result.height == size)
    }

    @Test("Invert Chaining with Grayscale")
    func invertWithGrayscale() throws {
        guard let engine = CommonMetalEngine() else {
            throw MetalEngineError.generalError(message: "Failed to create Metal engine")
        }

        let size = 256
        let testData = createMockImageData(width: size, height: size)

        // Configure pipeline: grayscale then invert
        let configuredEngine = try engine
            .withRawData(width: size, height: size)
            .grayscale(strategy: .weighted)
            .invert()

        // Execute with test data
        let result = try configuredEngine.execute(data: testData)

        #expect(result.width == size)
        #expect(result.height == size)
    }

    @Test("Invert Performance")
    func invertPerformance() throws {
        guard let engine = CommonMetalEngine() else {
            throw MetalEngineError.generalError(message: "Failed to create Metal engine")
        }

        let size = 512
        let testData = createMockImageData(width: size, height: size)

        let configuredEngine = try engine
            .withRawData(width: size, height: size)
            .invert()

        // Measure performance
        let startTime = CFAbsoluteTimeGetCurrent()
        _ = try configuredEngine.execute(data: testData)
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime

        // Should complete in under 1 second for a 512x512 image (including shader compilation)
        #expect(timeElapsed < 1.0)
    }
}
