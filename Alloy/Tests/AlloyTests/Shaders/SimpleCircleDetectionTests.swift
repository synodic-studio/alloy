import Testing
import Foundation
import SwiftUI

@testable import Alloy

//@Test("Simple Circle Detection Basic Functionality")
//func testSimpleCircleDetectionBasic() async throws {
//    guard let engine = CommonMetalEngine() else {
//        throw MetalEngineError.generalError(message: "Failed to create Metal engine")
//    }
//    
//    let size = 128
//    let image = await MainActor.run {
//        CircleDetectionPreview.generateTestImageWithCircles(size: .init(width: size, height: size))
//    }
//    let testData = image.tiffRepresentation!
//    
//    let configuredEngine = try engine
//        .withRGBAData(width: size, height: size)
//        .grayscale(strategy: .weighted)
//    
//    let result = try await configuredEngine.simpleCircleDetection(
//        data: testData,
//        minDiameter: 10,
//        maxDiameter: 60,
//        threshold: 0.5,
//        maxCircles: 10
//    )
//    
//    #expect(result.circleCount > 0)
//    #expect(result.circleCount <= 7)
//} 
