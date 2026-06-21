import Foundation
import Metal
import Testing

@testable import Alloy

@Suite("Donut Mask Shader Tests")
struct DonutMaskTests {
    @Test("Donut Mask Operation")
    func donutMaskOperation() throws {
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

    @Test("Donut Mask Feathered Edge Produces Partial Alpha")
    func donutMaskFeatheredEdge() throws {
        guard let engine = CommonMetalEngine() else {
            throw MetalEngineError.generalError(message: "Failed to create Metal engine")
        }

        let size = 256
        let testData = createMockImageData(width: size, height: size)

        // Center defaults to (128, 128); outer radius is half the width (128).
        // x=255 is 1px inside the outer boundary, within the 2px feather band.
        let configuredEngine = try engine
            .withRawData(width: size, height: size)
            .donutMask(innerRadius: 50, featherPixels: 2)

        let result = try configuredEngine.execute(data: testData)

        var pixel = [UInt8](repeating: 0, count: 4)
        let region = MTLRegionMake2D(255, 128, 1, 1)
        result.texture.getBytes(&pixel, bytesPerRow: 4, from: region, mipmapLevel: 0)

        let alpha = pixel[3]
        #expect(alpha > 0 && alpha < 255, "Expected partial alpha near the feathered outer boundary, got \(alpha)")
    }

    @Test("Donut Mask Default Feather Stays Hard-Edged")
    func donutMaskDefaultFeatherIsHardEdge() throws {
        guard let engine = CommonMetalEngine() else {
            throw MetalEngineError.generalError(message: "Failed to create Metal engine")
        }

        let size = 256
        let testData = createMockImageData(width: size, height: size)

        let configuredEngine = try engine
            .withRawData(width: size, height: size)
            .donutMask(innerRadius: 50)

        let result = try configuredEngine.execute(data: testData)

        var pixel = [UInt8](repeating: 0, count: 4)
        let region = MTLRegionMake2D(255, 128, 1, 1)
        result.texture.getBytes(&pixel, bytesPerRow: 4, from: region, mipmapLevel: 0)

        let alpha = pixel[3]
        #expect(alpha == 0 || alpha == 255, "Default (featherPixels: 0) should stay binary, got \(alpha)")
    }
}
