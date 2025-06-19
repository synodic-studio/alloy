import Testing
import Foundation

@testable import Alloy

// MARK: - Basic Operation Tests

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

@Test("Square Crop Operation")
func testSquareCropOperation() throws {
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

@Test("Donut Mask Operation")
func testDonutMaskOperation() throws {
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

// MARK: - Error Handling Tests

@Test("Invalid Dimensions Throws Error")
func testInvalidDimensionsThrowsError() {
    guard let engine = CommonMetalEngine() else {
        #expect(Bool(false), "Failed to create Metal engine")
        return
    }
    
    #expect(throws: MetalEngineError.self) {
        _ = try engine.withRawData(width: 0, height: 100)
    }
}

@Test("Invalid Bit Depth Throws Error")
func testInvalidBitDepthThrowsError() {
    guard let engine = CommonMetalEngine() else {
        #expect(Bool(false), "Failed to create Metal engine")
        return
    }
    
    #expect(throws: MetalEngineError.self) {
        _ = try engine.withRawData(width: 100, height: 100, bitDepth: 12)
    }
}

@Test("No Operations Throws Error")
func testNoOperationsThrowsError() {
    guard let engine = CommonMetalEngine() else {
        #expect(Bool(false), "Failed to create Metal engine")
        return
    }
    
    let testData = Data(repeating: 128, count: 100 * 100) // 8-bit test data
    let configuredEngine = try! engine.withRawData(width: 100, height: 100)
    
    #expect(throws: MetalEngineError.self) {
        _ = try configuredEngine.execute(data: testData)
    }
}

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

// MARK: - Performance Tests

@Test("Performance of Chained Operations")
func testPerformanceOfChainedOperations() throws {
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

// MARK: - Helper Methods

private func createMockRawData(width: Int, height: Int, bitDepth: Int) -> Data {
    let bytesPerPixel = bitDepth == 16 ? 2 : 1
    let count = width * height * bytesPerPixel
    return Data(repeating: 128, count: count)
}

private func createMockImageData(width: Int, height: Int) -> Data {
    let bytesPerPixel = 4 // RGBA
    let count = width * height * bytesPerPixel
    return Data(repeating: 255, count: count)
}
