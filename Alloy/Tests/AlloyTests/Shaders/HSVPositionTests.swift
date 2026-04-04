import Foundation
import Testing

@testable import Alloy

@Suite("HSV Position Shader Tests")
struct HSVPositionTests {
    @Test("HSV Position Operation Basic Functionality")
    func hSVPositionOperation() throws {
        guard let engine = CommonMetalEngine() else {
            throw MetalEngineError.generalError(message: "Failed to create Metal engine")
        }

        let width = 256
        let height = 256
        let testData = createMockImageData(width: width, height: height)

        // Configure pipeline with HSV positioning
        let configuredEngine = try engine
            .withRawData(width: width, height: height)
            .hsvPosition(xAxis: .hue, yAxis: .saturation, width: 512, height: 512, pixelSize: 2)

        // Execute with test data
        let result = try configuredEngine.execute(data: testData)

        #expect(result.width == 512)
        #expect(result.height == 512)
    }

    @Test("HSV Position Validation")
    func hSVPositionValidation() throws {
        guard let engine = CommonMetalEngine() else {
            throw MetalEngineError.generalError(message: "Failed to create Metal engine")
        }

        // Configure basic pipeline
        let basicEngine = try engine.withRawData(width: 256, height: 256)

        // Test invalid dimensions
        #expect(throws: MetalEngineError.self) {
            _ = try basicEngine.hsvPosition(xAxis: .hue, yAxis: .saturation, width: 0, height: 512)
        }

        // Test same axis for X and Y
        #expect(throws: MetalEngineError.self) {
            _ = try basicEngine.hsvPosition(xAxis: .hue, yAxis: .hue, width: 512, height: 512)
        }

        // Test invalid pixel size
        #expect(throws: MetalEngineError.self) {
            _ = try basicEngine.hsvPosition(xAxis: .hue, yAxis: .saturation, width: 512, height: 512, pixelSize: 0)
        }
    }

    @Test("HSV Position Chaining")
    func hSVPositionChaining() throws {
        guard let engine = CommonMetalEngine() else {
            throw MetalEngineError.generalError(message: "Failed to create Metal engine")
        }

        let rawWidth = 512
        let rawHeight = 512
        let testData = createMockRawData(width: rawWidth, height: rawHeight, bitDepth: 8)

        // Configure chained pipeline
        let configuredEngine = try engine
            .withRawData(width: rawWidth, height: rawHeight)
            .debayerRGGB()
            .hsvPosition(xAxis: .saturation, yAxis: .value, width: 300, height: 300, pixelSize: 3)

        // Execute with test data
        let result = try configuredEngine.execute(data: testData)

        #expect(result.width == 300)
        #expect(result.height == 300)
    }

    @Test("HSV Position Preset Methods")
    func hSVPositionPresets() throws {
        guard let engine = CommonMetalEngine() else {
            throw MetalEngineError.generalError(message: "Failed to create Metal engine")
        }

        let width = 256
        let height = 256
        let testData = createMockImageData(width: width, height: height)

        // Test Saturation-Value preset
        _ = try engine
            .withRawData(width: width, height: height)
            .hsvPositionSaturationValue(pixelSize: 2)

        // Test Hue-Value preset with forced saturation
        _ = try engine
            .reset()
            .withRawData(width: width, height: height)
            .hsvPositionHueValue(pixelSize: 3, forceFullSaturation: true)

        // Test Hue-Saturation preset with forced value
        let thirdEngine = try engine
            .reset()
            .withRawData(width: width, height: height)
            .hsvPositionHueSaturation(pixelSize: 1, forceFullValue: true)

        // Execute with test data to verify functionality
        _ = try thirdEngine.execute(data: testData)
    }
}
