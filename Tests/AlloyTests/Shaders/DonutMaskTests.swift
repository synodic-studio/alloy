import Foundation
import Testing

@testable import Alloy

@Suite("Donut Mask Shader Tests")
struct DonutMaskTests {
    @Test("Donut Mask Operation")
    func donutMaskOperation() throws {
        guard let engine = CommonMetalEngine() else {
            throw MetalEngineError.generalError(message: "Failed to create Metal engine")
        }

        let size = 256
        let testData = createMockImageData(width: size, height: size)

        // Configure pipeline
        let configuredEngine = try engine
            .withRawData(width: size, height: size)
            .donutMask(innerRadius: 50)

        // Execute with test data
        let result = try configuredEngine.execute(data: testData)

        #expect(result.width == size)
        #expect(result.height == size)
    }
}
