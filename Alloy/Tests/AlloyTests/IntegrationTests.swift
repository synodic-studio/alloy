import Testing
import Foundation

@testable import Alloy

// MARK: - Chained Operation Tests

@Test("Chained Operations")
func testChainedOperations() throws {
    guard let engine = CommonMetalEngine() else {
        throw MetalEngineError.generalError(message: "Failed to create Metal engine")
    }
    
    let rawWidth = 512
    let rawHeight = 512
    let testData = createMockRawData(width: rawWidth, height: rawHeight, bitDepth: 8)
    
    // Configure pipeline
    let configuredEngine = try engine
        .withRawData(width: rawWidth, height: rawHeight)
        .debayerRGGB()
        .squareCrop(center: (x: 128, y: 128), sideLength: 200)
        .donutMask(innerRadius: 50)
    
    // Execute with test data
    let result = try configuredEngine.execute(data: testData)
    
    #expect(result.width == 200)
    #expect(result.height == 200)
}