import Testing
import Foundation

@testable import Alloy

@Test("Circle Detection Basic Functionality")
func testCircleDetectionBasic() throws {
    guard let engine = CommonMetalEngine() else {
        throw MetalEngineError.generalError(message: "Failed to create Metal engine")
    }
    
    let size = 400
    let testData = createMockImageWithCircles(width: size, height: size)
    
    // Configure pipeline with circle detection
    let configuredEngine = try engine
        .withRGBAData(width: size, height: size)
        .grayscale(strategy: .weighted)
    
    // Execute circle detection
    let result = try configuredEngine.executeWithCircleDetection(
        data: testData,
        minDiameter: 10,
        maxDiameter: 50,
        threshold: 0.3,
        maxCircles: 50
    )
    
    #expect(result.width == size)
    #expect(result.height == size)
    #expect(result.circleCount >= 0) // Should not crash and return valid count
}

@Test("Circle Detection Parameter Validation") 
func testCircleDetectionValidation() throws {
    guard let engine = CommonMetalEngine() else {
        throw MetalEngineError.generalError(message: "Failed to create Metal engine")
    }
    
    let size = 256
    let configuredEngine = try engine.withRGBAData(width: size, height: size)
    
    let testData = createMockImageWithCircles(width: size, height: size)
    
    // Test invalid diameter range
    #expect(throws: MetalEngineError.self) {
        _ = try configuredEngine.executeWithCircleDetection(data: testData, minDiameter: 50, maxDiameter: 10)
    }
    
    // Test invalid threshold
    #expect(throws: MetalEngineError.self) {
        _ = try configuredEngine.executeWithCircleDetection(data: testData, threshold: 1.5)
    }
    
    // Test invalid maxCircles
    #expect(throws: MetalEngineError.self) {
        _ = try configuredEngine.executeWithCircleDetection(data: testData, maxCircles: 0)
    }
}

@Test("Circle Detection with Invert")
func testCircleDetectionWithInvert() throws {
    guard let engine = CommonMetalEngine() else {
        throw MetalEngineError.generalError(message: "Failed to create Metal engine")
    }
    
    let size = 300
    let testData = createMockImageWithCircles(width: size, height: size)
    
    // Configure pipeline: grayscale, invert, then detect circles
    let configuredEngine = try engine
        .withRGBAData(width: size, height: size)
        .grayscale(strategy: .weighted)
        .invert()
    
    // Execute circle detection
    let result = try configuredEngine.executeWithCircleDetection(
        data: testData,
        minDiameter: 14,
        maxDiameter: 28,
        threshold: 0.4
    )
    
    #expect(result.width == size)
    #expect(result.height == size)
}

// MARK: - Helper Functions

func createMockImageWithCircles(width: Int, height: Int) -> Data {
    var data = Data(count: width * height * 4) // RGBA
    
    // Fill with black background
    for i in 0..<(width * height) {
        let offset = i * 4
        data[offset] = 0     // R
        data[offset + 1] = 0 // G
        data[offset + 2] = 0 // B
        data[offset + 3] = 255 // A
    }
    
    // Add a few white circles for testing
    let circles = [
        (x: width / 4, y: height / 4, radius: 20),
        (x: 3 * width / 4, y: height / 4, radius: 15),
        (x: width / 2, y: 3 * height / 4, radius: 25)
    ]
    
    for circle in circles {
        let cx = circle.x
        let cy = circle.y
        let r = circle.radius
        
        for y in max(0, cy - r)..<min(height, cy + r) {
            for x in max(0, cx - r)..<min(width, cx + r) {
                let dx = x - cx
                let dy = y - cy
                let distance = sqrt(Double(dx * dx + dy * dy))
                
                // Create a circle with some thickness (ring)
                if distance >= Double(r - 3) && distance <= Double(r + 1) {
                    let offset = (y * width + x) * 4
                    data[offset] = 255     // R - white
                    data[offset + 1] = 255 // G - white
                    data[offset + 2] = 255 // B - white
                    data[offset + 3] = 255 // A
                }
            }
        }
    }
    
    return data
} 
