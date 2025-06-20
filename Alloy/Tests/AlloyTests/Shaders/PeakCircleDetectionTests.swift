import Testing
import Foundation

@testable import Alloy

@Test("Peak Circle Detection Basic Functionality")
func testPeakCircleDetectionBasic() async throws {
    guard let engine = CommonMetalEngine() else {
        throw MetalEngineError.generalError(message: "Failed to create Metal engine")
    }
    
    let size = 400
    let testData = createMockImageWithCircles(width: size, height: size)
    
    let configuredEngine = try engine
        .withRGBAData(width: size, height: size)
        .grayscale(strategy: .weighted)
    
    let result = try await configuredEngine.executeWithPeakCircleDetection(
        data: testData,
        minDiameter: 10,
        maxDiameter: 50,
        correlationThreshold: 0.6,
        maxPeaks: 50
    )
    
    #expect(result.width == size)
    #expect(result.height == size)
    #expect(result.circleCount >= 0)
}

@Test("Peak Circle Detection Parameter Validation") 
func testPeakCircleDetectionValidation() async throws {
    guard let engine = CommonMetalEngine() else {
        throw MetalEngineError.generalError(message: "Failed to create Metal engine")
    }
    
    let size = 256
    let configuredEngine = try engine.withRGBAData(width: size, height: size)
    let testData = createMockImageWithCircles(width: size, height: size)
    
    await #expect(throws: MetalEngineError.self) {
        _ = try await configuredEngine.executeWithPeakCircleDetection(data: testData, minDiameter: 50, maxDiameter: 10)
    }
    
    await #expect(throws: MetalEngineError.self) {
        _ = try await configuredEngine.executeWithPeakCircleDetection(data: testData, correlationThreshold: 1.5)
    }
    
    await #expect(throws: MetalEngineError.self) {
        _ = try await configuredEngine.executeWithPeakCircleDetection(data: testData, maxPeaks: 0)
    }
} 