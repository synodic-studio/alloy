import Foundation
import Testing

@testable import Alloy

@Suite
struct EngineErrorTests {
    @Test("Invalid Dimensions Throws Error")
    func invalidDimensionsThrowsError() {
        guard let engine = CommonMetalEngine() else {
            #expect(Bool(false), "Failed to create Metal engine")
            return
        }

        #expect(throws: MetalEngineError.self) {
            _ = try engine.withRawData(width: 0, height: 100)
        }
    }

    @Test("Invalid Bit Depth Throws Error")
    func invalidBitDepthThrowsError() {
        guard let engine = CommonMetalEngine() else {
            #expect(Bool(false), "Failed to create Metal engine")
            return
        }

        #expect(throws: MetalEngineError.self) {
            _ = try engine.withRawData(width: 100, height: 100, bitDepth: 12)
        }
    }
}
