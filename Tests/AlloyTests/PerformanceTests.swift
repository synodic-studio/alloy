import Foundation
import Testing

@testable import Alloy

@Suite("Performance Tests")
struct PerformanceTests {
    @Test("Performance of Chained Operations")
    func performanceOfChainedOperations() throws {
        guard let engine = CommonMetalEngine() else {
            throw MetalEngineError.generalError(message: "Failed to create Metal engine")
        }

        let testData = createMockRawData(width: 2048, height: 2048, bitDepth: 8)

        // Configure pipeline once
        let configuredEngine = try engine
            .withRawData(width: 2048, height: 2048)
            .debayerRGGB()
            .squareCrop(center: (x: 512, y: 512), sideLength: 512)
            .donutMask(innerRadius: 100)

        // Note: Swift Testing doesn't have a direct equivalent to measure{}
        // For performance testing, consider using XCTMetric or separate performance tests
        _ = try configuredEngine.execute(data: testData)
    }
}
