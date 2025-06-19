import Testing
import Foundation

@testable import Alloy

// MARK: - Engine Reuse Tests

@Test("Engine Reset")
func testEngineReset() throws {
    guard let engine = CommonMetalEngine() else {
        throw MetalEngineError.generalError(message: "Failed to create Metal engine")
    }
    
    let testData = createMockImageData(width: 256, height: 256)
    
    // First pipeline configuration
    let firstEngine = try engine
        .withRawData(width: 256, height: 256)
        .squareCrop(center: (x: 128, y: 128), sideLength: 128)
    
    // Execute first pipeline
    _ = try firstEngine.execute(data: testData)
    
    // Reset and configure new pipeline
    let secondEngine = try engine
        .reset()
        .withRawData(width: 256, height: 256)
        .donutMask(innerRadius: 50)
    
    // Execute second pipeline
    let result = try secondEngine.execute(data: testData)
    
    #expect(result.width == 256)
    #expect(result.height == 256)
}