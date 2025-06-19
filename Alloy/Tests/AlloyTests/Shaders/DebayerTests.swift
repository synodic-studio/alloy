import Testing
import Foundation

@testable import Alloy

@Test("Debayer Operation")
func testDebayerOperation() throws {
    guard let engine = CommonMetalEngine() else {
        throw MetalEngineError.generalError(message: "Failed to create Metal engine")
    }
    
    let testData = Data(repeating: 128, count: 100 * 100) // 8-bit test data
    
    // Configure pipeline
    let configuredEngine = try engine
        .withRawData(width: 100, height: 100, bitDepth: 8)
        .debayerRGGB(bitDepth: 8)
    
    // Execute with test data
    let result = try configuredEngine.execute(data: testData)
    
    #expect(result.width == 50) // Width is halved by debayering
    #expect(result.height == 50) // Height is halved by debayering
} 