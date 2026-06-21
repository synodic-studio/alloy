import Foundation
import Metal
import Testing

@testable import Alloy

@Suite("Integration Tests")
struct IntegrationTests {
    @Test("Chained Operations")
    func chainedOperations() throws {
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

    /// GrayscaleTests only exercises grayscale()'s binary cutoff on an isolated
    /// 1x1 pixel. This mirrors GravityWell's actual detection chain (squareCrop ->
    /// donutMask -> grayscale(blackThreshold == whiteThreshold) -> erosion ->
    /// connectedComponents) against a multi-pixel image with a real radial
    /// brightness gradient, to confirm the binary guarantee survives being
    /// chained after crop/mask and that the resulting blob is still detectable.
    @Test("Binary threshold survives full preprocessing pipeline and stays detectable")
    func thresholdPipelineStaysBinaryAndDetectsBlob() throws {
        let sourceSize = 100
        let cropSide = 64
        let cropCenter = (x: sourceSize / 2, y: sourceSize / 2)
        let blobCenter = Float(cropSide / 2)
        let blobRadius = 8.0
        let threshold = 0.5

        let sourceData = makeRadialGradientImage(
            width: sourceSize,
            height: sourceSize,
            center: (x: sourceSize / 2, y: sourceSize / 2),
            radius: blobRadius,
        )

        guard let engine = CommonMetalEngine() else {
            throw MetalEngineError.generalError(message: "Failed to create Metal engine")
        }

        let thresholdResult = try engine
            .withRGBAData(width: sourceSize, height: sourceSize)
            .squareCrop(center: cropCenter, sideLength: cropSide)
            .donutMask(innerRadius: 0)
            .grayscale(strategy: .average, blackThreshold: threshold, whiteThreshold: threshold)
            .erosion(iterations: 1, connectivity: .eight)
            .execute(data: sourceData)

        let outputPixels = try pixels(from: thresholdResult.texture)

        // The core "no ramp" guarantee: every pixel must be exactly 0 or 255,
        // never an intermediate gray, even after crop + mask + erosion.
        for pixel in outputPixels {
            #expect(
                pixel.r == 0 || pixel.r == 255,
                "Expected binary output, got intermediate value \(pixel.r)",
            )
        }

        guard let connectedComponentsEngine = CommonMetalEngine() else {
            throw MetalEngineError.generalError(message: "Failed to create Metal engine")
        }

        let detectionResult = try connectedComponentsEngine
            .withRGBAData(width: cropSide, height: cropSide)
            .executeConnectedComponentsWithTexture(
                inputTexture: thresholdResult.texture,
                maxComponents: 10,
                maxPixelsPerBlob: 200,
            )

        #expect(detectionResult.centroids.count == 1, "Should detect exactly one blob")

        if let centroid = detectionResult.centroids.first {
            #expect(abs(centroid.x - blobCenter) < 2.0, "Centroid X should land on the blob center")
            #expect(abs(centroid.y - blobCenter) < 2.0, "Centroid Y should land on the blob center")
            #expect(centroid.pixelCount > 0, "Detected blob should have nonzero area")
        }
    }

    // MARK: - Helpers

    /// Builds an RGBA image with a radial brightness gradient (full intensity
    /// at the center, fading to 0 at `radius`), so the input to grayscale()
    /// spans a continuous range of values rather than a few discrete ones.
    private func makeRadialGradientImage(
        width: Int,
        height: Int,
        center: (x: Int, y: Int),
        radius: Double,
    ) -> Data {
        var data = Data(capacity: width * height * 4)

        for y in 0 ..< height {
            for x in 0 ..< width {
                let dx = Double(x - center.x)
                let dy = Double(y - center.y)
                let distance = (dx * dx + dy * dy).squareRoot()
                let intensity = max(0.0, min(1.0, 1.0 - distance / radius))
                let value = UInt8(intensity * 255.0)
                data.append(contentsOf: [value, value, value, 255])
            }
        }

        return data
    }

    private func pixels(from texture: MTLTexture) throws -> [Pixel] {
        let width = texture.width
        let height = texture.height

        guard texture.pixelFormat == .rgba8Uint else {
            throw MetalEngineError.generalError(message: "Unsupported pixel format: \(texture.pixelFormat)")
        }

        let bytesPerRow = width * 4
        var data = Data(count: bytesPerRow * height)

        data.withUnsafeMutableBytes { ptr in
            texture.getBytes(
                ptr.baseAddress!,
                bytesPerRow: bytesPerRow,
                from: MTLRegionMake2D(0, 0, width, height),
                mipmapLevel: 0,
            )
        }

        var pixels: [Pixel] = []
        for i in stride(from: 0, to: data.count, by: 4) {
            pixels.append(Pixel(r: data[i], g: data[i + 1], b: data[i + 2], a: data[i + 3]))
        }

        return pixels
    }
}

private struct Pixel: Equatable {
    let r, g, b, a: UInt8
}
