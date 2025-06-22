import Testing
import AppKit
import Metal

@testable import Alloy

@Suite("Erosion Shader Tests")
struct ErosionTests {
    
    // MARK: - Basic Erosion Tests
    
    @Test("Single iteration 4-connection erosion works correctly")
    func testSingleIteration4ConnectionErosion() throws {
        // Create a simple 3x3 white square with black border
        let testImage = createTestImage(width: 5, height: 5, pattern: .whiteSquareWithBorder)
        
        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }
        
        let result = try engine
            .withRGBAData(width: 5, height: 5)
            .erosion(iterations: 1, connectivity: .four)
            .execute(data: testImage)
        
        let pixels = try pixels(from: result.texture)
        
        // Center pixel should be eroded (become black) due to neighboring black pixels
        let centerPixel = pixels[2 * 5 + 2] // Row 2, Col 2 (0-indexed)
        #expect(centerPixel.r == 0, "Center pixel should be eroded to black")
    }
    
    @Test("Single iteration 8-connection erosion works correctly")
    func testSingleIteration8ConnectionErosion() throws {
        // Create a simple 3x3 white square with black border
        let testImage = createTestImage(width: 5, height: 5, pattern: .whiteSquareWithBorder)
        
        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }
        
        let result = try engine
            .withRGBAData(width: 5, height: 5)
            .erosion(iterations: 1, connectivity: .eight)
            .execute(data: testImage)
        
        let pixels = try pixels(from: result.texture)
        
        // Center pixel should be eroded (become black) due to neighboring black pixels
        let centerPixel = pixels[2 * 5 + 2] // Row 2, Col 2 (0-indexed)
        #expect(centerPixel.r == 0, "Center pixel should be eroded to black")
    }
    
    @Test("8-connection erodes more aggressively than 4-connection")
    func testConnectivityDifference() throws {
        // Create a diagonal pattern where 8-connectivity should erode more
        let testImage = createTestImage(width: 7, height: 7, pattern: .diagonalPattern)
        
        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }
        
        // Test with 4-connection
        let result4 = try engine
            .withRGBAData(width: 7, height: 7)
            .erosion(iterations: 1, connectivity: .four)
            .execute(data: testImage)
        
        let pixels4 = try pixels(from: result4.texture)
        
        // Test with 8-connection
        let result8 = try CommonMetalEngine()!
            .withRGBAData(width: 7, height: 7)
            .erosion(iterations: 1, connectivity: .eight)
            .execute(data: testImage)
        
        let pixels8 = try pixels(from: result8.texture)
        
        // Count white pixels - 8-connection should result in fewer white pixels
        let whiteCount4 = pixels4.filter { $0.r > 0 }.count
        let whiteCount8 = pixels8.filter { $0.r > 0 }.count
        
        #expect(whiteCount8 <= whiteCount4, "8-connection should erode more aggressively than 4-connection")
    }
    
    @Test("Multiple iterations increase erosion effect")
    func testMultipleIterations() throws {
        // Create a larger white area
        let testImage = createTestImage(width: 7, height: 7, pattern: .whiteSquare)
        
        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }
        
        // Test with 1 iteration
        let result1 = try engine
            .withRGBAData(width: 7, height: 7)
            .erosion(iterations: 1, connectivity: .eight)
            .execute(data: testImage)
        
        let pixels1 = try pixels(from: result1.texture)
        
        // Test with 2 iterations
        let result2 = try CommonMetalEngine()!
            .withRGBAData(width: 7, height: 7)
            .erosion(iterations: 2, connectivity: .eight)
            .execute(data: testImage)
        
        let pixels2 = try pixels(from: result2.texture)
        
        // Count white pixels - should decrease with more iterations
        let whiteCount1 = pixels1.filter { $0.r > 0 }.count
        let whiteCount2 = pixels2.filter { $0.r > 0 }.count
        
        #expect(whiteCount2 <= whiteCount1, "More iterations should result in fewer white pixels")
    }
    
    @Test("Erosion preserves alpha channel")
    func testAlphaPreservation() throws {
        let testImage = createTestImageWithAlpha()
        
        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }
        
        let result = try engine
            .withRGBAData(width: 3, height: 3)
            .erosion(iterations: 1, connectivity: .eight)
            .execute(data: testImage)
        
        let pixels = try pixels(from: result.texture)
        
        // Check that alpha values are preserved
        for pixel in pixels {
            #expect(pixel.a == 128, "Alpha channel should be preserved")
        }
    }
    
    @Test("All black image remains black")
    func testAllBlackImage() throws {
        let testImage = createTestImage(width: 5, height: 5, pattern: .allBlack)
        
        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }
        
        let result = try engine
            .withRGBAData(width: 5, height: 5)
            .erosion(iterations: 3, connectivity: .eight)
            .execute(data: testImage)
        
        let pixels = try pixels(from: result.texture)
        
        // All pixels should remain black
        for pixel in pixels {
            #expect(pixel.r == 0 && pixel.g == 0 && pixel.b == 0, "Black pixels should remain black")
        }
    }
    
    @Test("All white image with no black neighbors remains white")
    func testAllWhiteImage() throws {
        let testImage = createTestImage(width: 5, height: 5, pattern: .allWhite)
        
        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }
        
        let result = try engine
            .withRGBAData(width: 5, height: 5)
            .erosion(iterations: 1, connectivity: .eight)
            .execute(data: testImage)
        
        let pixels = try pixels(from: result.texture)
        
        // All pixels should remain white (no erosion occurs)
        for pixel in pixels {
            #expect(pixel.r == 255 && pixel.g == 255 && pixel.b == 255, "White pixels with no black neighbors should remain white")
        }
    }
    
    // MARK: - Edge Cases
    
    @Test("Single pixel erosion")
    func testSinglePixelErosion() throws {
        // Create 1x1 white pixel
        let testImage = Data([255, 255, 255, 255])
        
        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }
        
        let result = try engine
            .withRGBAData(width: 1, height: 1)
            .erosion(iterations: 1, connectivity: .eight)
            .execute(data: testImage)
        
        let pixels = try pixels(from: result.texture)
        
        // Single pixel with no neighbors should remain unchanged
        #expect(pixels[0].r == 255, "Single pixel should remain white")
    }
    
    // MARK: - Validation Tests
    
    @Test("Invalid iterations parameter throws error")
    func testInvalidIterations() throws {
        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }
        
        // Test negative iterations
        #expect(throws: MetalEngineError.self) {
            try engine.erosion(iterations: 0, connectivity: .eight)
        }
        
        // Test too many iterations
        #expect(throws: MetalEngineError.self) {
            try engine.erosion(iterations: 21, connectivity: .eight)
        }
    }
    
    // MARK: - Helper Methods
    
    private enum TestPattern {
        case allBlack
        case allWhite
        case whiteSquare
        case whiteSquareWithBorder
        case diagonalPattern
    }
    
    private func createTestImage(width: Int, height: Int, pattern: TestPattern) -> Data {
        var data = Data(capacity: width * height * 4)
        
        for y in 0..<height {
            for x in 0..<width {
                let (r, g, b): (UInt8, UInt8, UInt8)
                
                switch pattern {
                case .allBlack:
                    (r, g, b) = (0, 0, 0)
                case .allWhite:
                    (r, g, b) = (255, 255, 255)
                case .whiteSquare:
                    // Black border, white interior
                    if x == 0 || x == width - 1 || y == 0 || y == height - 1 {
                        (r, g, b) = (0, 0, 0)
                    } else {
                        (r, g, b) = (255, 255, 255)
                    }
                case .whiteSquareWithBorder:
                    // Create a pattern where center pixel has direct 4-connected black neighbors
                    // For a 5x5 grid, create a cross pattern with black pixels adjacent to center
                    if (x == 2 && (y == 1 || y == 3)) || (y == 2 && (x == 1 || x == 3)) {
                        (r, g, b) = (0, 0, 0)  // Black cross around center
                    } else {
                        (r, g, b) = (255, 255, 255)  // White elsewhere
                    }
                case .diagonalPattern:
                    // Create diagonal black lines to test 8-connection vs 4-connection
                    if x == y || x == width - 1 - y {
                        (r, g, b) = (0, 0, 0)
                    } else {
                        (r, g, b) = (255, 255, 255)
                    }
                }
                
                data.append(contentsOf: [r, g, b, 255])
            }
        }
        
        return data
    }
    
    private func createTestImageWithAlpha() -> Data {
        var data = Data(capacity: 3 * 3 * 4)
        
        // Create 3x3 image with custom alpha
        for _ in 0..<9 {
            data.append(contentsOf: [255, 255, 255, 128]) // White with half alpha
        }
        
        return data
    }
    
    private func pixels(from texture: MTLTexture) throws -> [Pixel] {
        let width = texture.width
        let height = texture.height
        
        guard texture.pixelFormat == .rgba8Uint else {
            throw TestError.unsupportedPixelFormat(texture.pixelFormat)
        }
        
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let size = bytesPerRow * height
        var data = Data(count: size)
        
        data.withUnsafeMutableBytes { ptr in
            texture.getBytes(
                ptr.baseAddress!,
                bytesPerRow: bytesPerRow,
                from: MTLRegionMake2D(0, 0, width, height),
                mipmapLevel: 0
            )
        }
        
        var pixels: [Pixel] = []
        for i in stride(from: 0, to: data.count, by: 4) {
            pixels.append(Pixel(r: data[i], g: data[i+1], b: data[i+2], a: data[i+3]))
        }
        
        return pixels
    }
    
    enum TestError: Error {
        case engineInitializationFailed
        case unsupportedPixelFormat(MTLPixelFormat)
    }
}

private struct Pixel: Equatable {
    let r, g, b, a: UInt8
    
    init(r: UInt8, g: UInt8, b: UInt8, a: UInt8 = 255) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }
} 