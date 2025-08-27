import Foundation
import Testing

@testable import Alloy

@Suite("Square Crop Shader Tests")
struct SquareCropTests {
    @Test("Square Crop Operation")
    func squareCropOperation() throws {
        guard let engine = CommonMetalEngine() else {
            throw MetalEngineError.generalError(message: "Failed to create Metal engine")
        }

        let width = 256
        let height = 256
        let testData = createMockImageData(width: width, height: height)

        // Configure pipeline
        let configuredEngine = try engine
            .withRawData(width: width, height: height)
            .squareCrop(center: (x: 128, y: 128), sideLength: 128)

        // Execute with test data
        let result = try configuredEngine.execute(data: testData)

        #expect(result.width == 128)
        #expect(result.height == 128)
    }
}
