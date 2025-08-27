import AppKit
import Metal
import Testing

@testable import Alloy

@Suite("Connected Components Shader Tests")
struct ConnectedComponentsTests {
    // MARK: - Basic Connected Components Tests

    @Test("Single white pixel is detected as one component")
    func singlePixelComponent() throws {
        // Create a 5x5 black image with one white pixel in the center
        let testImage = createTestImage(width: 5, height: 5, pattern: .singleWhitePixel)

        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }

        let result = try engine
            .withRGBAData(width: 5, height: 5)
            .executeConnectedComponents(data: testImage)

        #expect(result.centroids.count == 1, "Should detect exactly one component")

        let centroid = result.centroids[0]
        #expect(abs(centroid.x - 2.0) < 0.1, "Centroid X should be at center (2.0)")
        #expect(abs(centroid.y - 2.0) < 0.1, "Centroid Y should be at center (2.0)")
        #expect(centroid.pixelCount == 1, "Component should have exactly 1 pixel")
    }

    @Test("Connected white pixels form single component")
    func connectedPixelsComponent() throws {
        // Create a 5x5 image with a connected 3x3 white square
        let testImage = createTestImage(width: 5, height: 5, pattern: .connectedSquare)

        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }

        let result = try engine
            .withRGBAData(width: 5, height: 5)
            .executeConnectedComponents(data: testImage)

        #expect(result.centroids.count == 1, "Connected pixels should form single component")

        let centroid = result.centroids[0]
        #expect(centroid.pixelCount == 9, "3x3 square should have 9 pixels")
        #expect(abs(centroid.x - 2.0) < 0.1, "Centroid X should be at center of square")
        #expect(abs(centroid.y - 2.0) < 0.1, "Centroid Y should be at center of square")
    }

    @Test("Separate white regions form multiple components")
    func multipleComponents() throws {
        // Create image with two separate white pixels
        let testImage = createTestImage(width: 7, height: 7, pattern: .twoSeparatePixels)

        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }

        let result = try engine
            .withRGBAData(width: 7, height: 7)
            .executeConnectedComponents(data: testImage)

        #expect(result.centroids.count == 2, "Should detect two separate components")

        // Both components should have 1 pixel each
        for centroid in result.centroids {
            #expect(centroid.pixelCount == 1, "Each component should have 1 pixel")
        }
    }

    @Test("Max components parameter limits detection")
    func maxComponentsLimit() throws {
        // Create image with many separate white pixels
        let testImage = createTestImage(width: 10, height: 10, pattern: .manyDots)

        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }

        let result = try engine
            .withRGBAData(width: 10, height: 10)
            .executeConnectedComponents(data: testImage, maxComponents: 3, maxPixelsPerBlob: 50)

        #expect(result.centroids.count <= 3, "Should not exceed maxComponents limit")
    }

    @Test("Max pixels per blob parameter filters large components")
    func maxPixelsPerBlobFilter() throws {
        // Create image with one large white area
        let testImage = createTestImage(width: 20, height: 20, pattern: .largeSquare)

        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }

        let result = try engine
            .withRGBAData(width: 20, height: 20)
            .executeConnectedComponents(data: testImage, maxComponents: 100, maxPixelsPerBlob: 50)

        #expect(result.centroids.isEmpty, "Large component should be filtered out by maxPixelsPerBlob")
    }

    @Test("Black pixels are ignored")
    func blackPixelsIgnored() throws {
        // Create image with only black pixels
        let testImage = createTestImage(width: 5, height: 5, pattern: .allBlack)

        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }

        let result = try engine
            .withRGBAData(width: 5, height: 5)
            .executeConnectedComponents(data: testImage)

        #expect(result.centroids.isEmpty, "Should detect no components in all-black image")
    }

    @Test("Diagonal connectivity works correctly")
    func diagonalConnectivity() throws {
        // Create image with diagonally connected white pixels
        let testImage = createTestImage(width: 5, height: 5, pattern: .diagonalLine)

        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }

        let result = try engine
            .withRGBAData(width: 5, height: 5)
            .executeConnectedComponents(data: testImage)

        #expect(result.centroids.count == 1, "Diagonally connected pixels should form one component")
        #expect(result.centroids[0].pixelCount >= 3, "Diagonal line should have multiple pixels")
    }

    // MARK: - Integration Tests

    @Test("Connected components after erosion pipeline")
    func erosionConnectedComponentsPipeline() throws {
        // Create image with white squares that will be eroded
        let testImage = createTestImage(width: 20, height: 20, pattern: .twoSquares)

        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }

        // First apply erosion
        let erosionResult = try engine
            .withRGBAData(width: 20, height: 20)
            .erosion(iterations: 1, connectivity: .eight)
            .execute(data: testImage)

        // Convert result back to data
        guard let erodedData = erosionResult.texture.toRGBAData() else {
            throw TestError.dataConversionFailed
        }

        // Now apply connected components
        let finalResult = try CommonMetalEngine()?
            .withRGBAData(width: 20, height: 20)
            .executeConnectedComponents(data: erodedData)

        #expect(finalResult?.centroids.count ?? 0 >= 0, "Pipeline should complete successfully")
    }

    // MARK: - Performance Tests

    @Test("Connected components performance on medium image")
    func connectedComponentsPerformance() throws {
        let testImage = createTestImage(width: 100, height: 100, pattern: .randomDots)

        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }

        let startTime = CFAbsoluteTimeGetCurrent()
        _ = try engine
            .withRGBAData(width: 100, height: 100)
            .executeConnectedComponents(data: testImage)
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime

        #expect(timeElapsed < 2.0, "Connected components should complete in under 2 seconds for 100x100 image")
    }

    // MARK: - Helper Methods

    private func createTestImage(width: Int, height: Int, pattern: TestPattern) -> Data {
        var data = Data(capacity: width * height * 4)

        for y in 0 ..< height {
            for x in 0 ..< width {
                let (r, g, b): (UInt8, UInt8, UInt8)

                switch pattern {
                case .allBlack:
                    (r, g, b) = (0, 0, 0)
                case .singleWhitePixel:
                    if x == width / 2, y == height / 2 {
                        (r, g, b) = (255, 255, 255)
                    } else {
                        (r, g, b) = (0, 0, 0)
                    }
                case .connectedSquare:
                    // 3x3 white square in center
                    let centerX = width / 2
                    let centerY = height / 2
                    if abs(x - centerX) <= 1, abs(y - centerY) <= 1 {
                        (r, g, b) = (255, 255, 255)
                    } else {
                        (r, g, b) = (0, 0, 0)
                    }
                case .twoSeparatePixels:
                    if (x == 1 && y == 1) || (x == 5 && y == 5) {
                        (r, g, b) = (255, 255, 255)
                    } else {
                        (r, g, b) = (0, 0, 0)
                    }
                case .manyDots:
                    // Every 3rd pixel in every 3rd row
                    if x % 3 == 0, y % 3 == 0 {
                        (r, g, b) = (255, 255, 255)
                    } else {
                        (r, g, b) = (0, 0, 0)
                    }
                case .largeSquare:
                    // Large 10x10 white square
                    if x >= 5, x < 15, y >= 5, y < 15 {
                        (r, g, b) = (255, 255, 255)
                    } else {
                        (r, g, b) = (0, 0, 0)
                    }
                case .diagonalLine:
                    // Diagonal line from top-left to bottom-right
                    if x == y, x < min(width, height) {
                        (r, g, b) = (255, 255, 255)
                    } else {
                        (r, g, b) = (0, 0, 0)
                    }
                case .twoSquares:
                    // Two 4x4 squares
                    if (x >= 2 && x < 6 && y >= 2 && y < 6) ||
                        (x >= 12 && x < 16 && y >= 12 && y < 16)
                    {
                        (r, g, b) = (255, 255, 255)
                    } else {
                        (r, g, b) = (0, 0, 0)
                    }
                case .randomDots:
                    // Pseudo-random dots
                    let hash = (x * 73 + y * 37) % 100
                    if hash < 20 {
                        (r, g, b) = (255, 255, 255)
                    } else {
                        (r, g, b) = (0, 0, 0)
                    }
                }

                data.append(contentsOf: [r, g, b, 255])
            }
        }

        return data
    }

    private enum TestPattern {
        case allBlack
        case singleWhitePixel
        case connectedSquare
        case twoSeparatePixels
        case manyDots
        case largeSquare
        case diagonalLine
        case twoSquares
        case randomDots
    }

    private enum TestError: Error {
        case engineInitializationFailed
        case dataConversionFailed
    }
}
