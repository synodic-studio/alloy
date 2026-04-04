import AppKit
import Metal
import Testing

@testable import Alloy

@Suite("Color Sampling Shader Tests")
struct ColorSamplingTests {
    // MARK: - Color Accuracy Tests (±5% validation requirement)

    @Test("Samples pure red color accurately")
    func samplePureRed() throws {
        // Create 10x10 image filled with pure red (255, 0, 0)
        let testImage = createSolidColorImage(width: 10, height: 10, color: (255, 0, 0))

        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }

        guard let texture = createTexture(from: testImage, width: 10, height: 10, device: engine.device) else {
            throw TestError.textureCreationFailed
        }

        let positions = [CGPoint(x: 5, y: 5)]
        let result = try engine.executeSampling(inputTexture: texture, positions: positions, radius: 3.0)

        #expect(result.colors.count == 1, "Should return one color")

        let color = result.colors[0]
        let tolerance: CGFloat = 0.05 // ±5% requirement

        #expect(abs(color.redComponent - 1.0) < tolerance, "Red component should be ~1.0 (±5%)")
        #expect(abs(color.greenComponent - 0.0) < tolerance, "Green component should be ~0.0 (±5%)")
        #expect(abs(color.blueComponent - 0.0) < tolerance, "Blue component should be ~0.0 (±5%)")
    }

    @Test("Samples pure green color accurately")
    func samplePureGreen() throws {
        let testImage = createSolidColorImage(width: 10, height: 10, color: (0, 255, 0))

        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }

        guard let texture = createTexture(from: testImage, width: 10, height: 10, device: engine.device) else {
            throw TestError.textureCreationFailed
        }

        let positions = [CGPoint(x: 5, y: 5)]
        let result = try engine.executeSampling(inputTexture: texture, positions: positions, radius: 3.0)

        let color = result.colors[0]
        let tolerance: CGFloat = 0.05

        #expect(abs(color.redComponent - 0.0) < tolerance, "Red component should be ~0.0 (±5%)")
        #expect(abs(color.greenComponent - 1.0) < tolerance, "Green component should be ~1.0 (±5%)")
        #expect(abs(color.blueComponent - 0.0) < tolerance, "Blue component should be ~0.0 (±5%)")
    }

    @Test("Samples pure blue color accurately")
    func samplePureBlue() throws {
        let testImage = createSolidColorImage(width: 10, height: 10, color: (0, 0, 255))

        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }

        guard let texture = createTexture(from: testImage, width: 10, height: 10, device: engine.device) else {
            throw TestError.textureCreationFailed
        }

        let positions = [CGPoint(x: 5, y: 5)]
        let result = try engine.executeSampling(inputTexture: texture, positions: positions, radius: 3.0)

        let color = result.colors[0]
        let tolerance: CGFloat = 0.05

        #expect(abs(color.redComponent - 0.0) < tolerance, "Red component should be ~0.0 (±5%)")
        #expect(abs(color.greenComponent - 0.0) < tolerance, "Green component should be ~0.0 (±5%)")
        #expect(abs(color.blueComponent - 1.0) < tolerance, "Blue component should be ~1.0 (±5%)")
    }

    @Test("Samples grayscale color accurately")
    func sampleGrayscale() throws {
        // Gray: (128, 128, 128) = ~0.5 normalized
        let testImage = createSolidColorImage(width: 10, height: 10, color: (128, 128, 128))

        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }

        guard let texture = createTexture(from: testImage, width: 10, height: 10, device: engine.device) else {
            throw TestError.textureCreationFailed
        }

        let positions = [CGPoint(x: 5, y: 5)]
        let result = try engine.executeSampling(inputTexture: texture, positions: positions, radius: 3.0)

        let color = result.colors[0]
        let tolerance: CGFloat = 0.05
        let expected: CGFloat = 128.0 / 255.0

        #expect(abs(color.redComponent - expected) < tolerance, "Red should be ~0.5 (±5%)")
        #expect(abs(color.greenComponent - expected) < tolerance, "Green should be ~0.5 (±5%)")
        #expect(abs(color.blueComponent - expected) < tolerance, "Blue should be ~0.5 (±5%)")
    }

    @Test("Samples multiple positions accurately")
    func sampleMultiplePositions() throws {
        // Create image with red top-left quadrant, green bottom-right quadrant
        let testImage = createQuadrantImage(width: 40, height: 40)

        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }

        guard let texture = createTexture(from: testImage, width: 40, height: 40, device: engine.device) else {
            throw TestError.textureCreationFailed
        }

        // Sample centers of each quadrant (well away from borders)
        let positions = [
            CGPoint(x: 10, y: 10), // Red region (top-left)
            CGPoint(x: 30, y: 30), // Green region (bottom-right)
        ]

        let result = try engine.executeSampling(inputTexture: texture, positions: positions, radius: 3.0)

        #expect(result.colors.count == 2, "Should return two colors")

        let tolerance: CGFloat = 0.1

        // First position (red quadrant)
        let color1 = result.colors[0]
        #expect(abs(color1.redComponent - 1.0) < tolerance, "First position should be red")
        #expect(abs(color1.greenComponent - 0.0) < tolerance, "First position red should have no green")

        // Second position (green quadrant)
        let color2 = result.colors[1]
        #expect(abs(color2.redComponent - 0.0) < tolerance, "Second position green should have no red")
        #expect(abs(color2.greenComponent - 1.0) < tolerance, "Second position should be green")
    }

    // MARK: - Edge Case Tests

    @Test("Empty positions array returns empty result")
    func emptyPositions() throws {
        let testImage = createSolidColorImage(width: 10, height: 10, color: (255, 0, 0))

        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }

        guard let texture = createTexture(from: testImage, width: 10, height: 10, device: engine.device) else {
            throw TestError.textureCreationFailed
        }

        let positions: [CGPoint] = []
        let result = try engine.executeSampling(inputTexture: texture, positions: positions, radius: 3.0)

        #expect(result.colors.isEmpty, "Should return empty colors array")
        #expect(result.positions.isEmpty, "Should return empty positions array")
    }

    @Test("Position at top-left corner (0,0)")
    func topLeftCornerPosition() throws {
        let testImage = createSolidColorImage(width: 10, height: 10, color: (255, 100, 50))

        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }

        guard let texture = createTexture(from: testImage, width: 10, height: 10, device: engine.device) else {
            throw TestError.textureCreationFailed
        }

        let positions = [CGPoint(x: 0, y: 0)]
        let result = try engine.executeSampling(inputTexture: texture, positions: positions, radius: 2.0)

        #expect(result.colors.count == 1, "Should handle corner position")

        // Should return valid color (not crash or return gray fallback)
        let color = result.colors[0]
        let tolerance: CGFloat = 0.1
        #expect(abs(color.redComponent - 1.0) < tolerance, "Should sample corner color correctly")
    }

    @Test("Position at bottom-right corner")
    func bottomRightCornerPosition() throws {
        let testImage = createSolidColorImage(width: 10, height: 10, color: (50, 200, 255))

        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }

        guard let texture = createTexture(from: testImage, width: 10, height: 10, device: engine.device) else {
            throw TestError.textureCreationFailed
        }

        let positions = [CGPoint(x: 9, y: 9)]
        let result = try engine.executeSampling(inputTexture: texture, positions: positions, radius: 2.0)

        #expect(result.colors.count == 1, "Should handle corner position")

        let color = result.colors[0]
        let tolerance: CGFloat = 0.1
        #expect(abs(color.blueComponent - 1.0) < tolerance, "Should sample corner color correctly")
    }

    @Test("Position outside image bounds returns gray fallback")
    func outsideBoundsPosition() throws {
        let testImage = createSolidColorImage(width: 10, height: 10, color: (255, 0, 0))

        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }

        guard let texture = createTexture(from: testImage, width: 10, height: 10, device: engine.device) else {
            throw TestError.textureCreationFailed
        }

        // Position completely outside with small radius
        let positions = [CGPoint(x: -10, y: -10)]
        let result = try engine.executeSampling(inputTexture: texture, positions: positions, radius: 1.0)

        #expect(result.colors.count == 1, "Should return result for out-of-bounds position")

        // Should return gray fallback (0.5, 0.5, 0.5)
        let color = result.colors[0]
        let tolerance: CGFloat = 0.05
        #expect(abs(color.redComponent - 0.5) < tolerance, "Out-of-bounds should return gray fallback")
        #expect(abs(color.greenComponent - 0.5) < tolerance, "Out-of-bounds should return gray fallback")
        #expect(abs(color.blueComponent - 0.5) < tolerance, "Out-of-bounds should return gray fallback")
    }

    @Test("Small radius (1.0) samples correctly")
    func smallRadius() throws {
        let testImage = createSolidColorImage(width: 10, height: 10, color: (200, 150, 100))

        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }

        guard let texture = createTexture(from: testImage, width: 10, height: 10, device: engine.device) else {
            throw TestError.textureCreationFailed
        }

        let positions = [CGPoint(x: 5, y: 5)]
        let result = try engine.executeSampling(inputTexture: texture, positions: positions, radius: 1.0)

        #expect(result.colors.count == 1, "Should handle small radius")

        let color = result.colors[0]
        let tolerance: CGFloat = 0.1
        #expect(abs(color.redComponent - (200.0 / 255.0)) < tolerance, "Small radius should sample correctly")
    }

    @Test("Large radius (10.0) samples correctly")
    func largeRadius() throws {
        let testImage = createSolidColorImage(width: 50, height: 50, color: (100, 200, 150))

        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }

        guard let texture = createTexture(from: testImage, width: 50, height: 50, device: engine.device) else {
            throw TestError.textureCreationFailed
        }

        let positions = [CGPoint(x: 25, y: 25)]
        let result = try engine.executeSampling(inputTexture: texture, positions: positions, radius: 10.0)

        #expect(result.colors.count == 1, "Should handle large radius")

        let color = result.colors[0]
        let tolerance: CGFloat = 0.1
        #expect(abs(color.greenComponent - (200.0 / 255.0)) < tolerance, "Large radius should sample correctly")
    }

    @Test("Many positions (100+) processes efficiently")
    func manyPositions() throws {
        let testImage = createSolidColorImage(width: 200, height: 200, color: (150, 150, 150))

        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }

        guard let texture = createTexture(from: testImage, width: 200, height: 200, device: engine.device) else {
            throw TestError.textureCreationFailed
        }

        // Generate 100 random positions
        var positions: [CGPoint] = []
        for i in 0 ..< 100 {
            let x = CGFloat((i * 17) % 180 + 10) // Pseudo-random but deterministic
            let y = CGFloat((i * 23) % 180 + 10)
            positions.append(CGPoint(x: x, y: y))
        }

        let result = try engine.executeSampling(inputTexture: texture, positions: positions, radius: 3.0)

        #expect(result.colors.count == 100, "Should process all 100 positions")
        #expect(result.positions.count == 100, "Should return all 100 positions")
    }

    // MARK: - Performance Tests

    @Test("Color sampling performance on typical usage")
    func colorSamplingPerformance() throws {
        // Typical GravityWell usage: 640x480 image, ~10 ball positions
        let testImage = createSolidColorImage(width: 640, height: 480, color: (255, 128, 64))

        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }

        guard let texture = createTexture(from: testImage, width: 640, height: 480, device: engine.device) else {
            throw TestError.textureCreationFailed
        }

        let positions = [
            CGPoint(x: 100, y: 100),
            CGPoint(x: 200, y: 150),
            CGPoint(x: 300, y: 200),
            CGPoint(x: 400, y: 250),
            CGPoint(x: 500, y: 300),
            CGPoint(x: 150, y: 350),
            CGPoint(x: 250, y: 100),
            CGPoint(x: 350, y: 400),
            CGPoint(x: 450, y: 200),
            CGPoint(x: 550, y: 350),
        ]

        let startTime = CFAbsoluteTimeGetCurrent()
        _ = try engine.executeSampling(inputTexture: texture, positions: positions, radius: 3.0)
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime

        // Should be extremely fast (<10ms for GPU operation)
        #expect(timeElapsed < 0.1, "Color sampling should complete in under 100ms for typical usage")
    }

    // MARK: - Helper Methods

    private func createSolidColorImage(width: Int, height: Int, color: (UInt8, UInt8, UInt8)) -> Data {
        var data = Data(capacity: width * height * 4)

        for _ in 0 ..< (width * height) {
            data.append(contentsOf: [color.0, color.1, color.2, 255])
        }

        return data
    }

    private func createQuadrantImage(width: Int, height: Int) -> Data {
        var data = Data(capacity: width * height * 4)

        let halfWidth = width / 2
        let halfHeight = height / 2

        for y in 0 ..< height {
            for x in 0 ..< width {
                let (r, g, b): (UInt8, UInt8, UInt8)

                // Top-left quadrant: Red
                if x < halfWidth, y < halfHeight {
                    (r, g, b) = (255, 0, 0)
                }
                // Bottom-right quadrant: Green
                else if x >= halfWidth, y >= halfHeight {
                    (r, g, b) = (0, 255, 0)
                }
                // Other quadrants: Black
                else {
                    (r, g, b) = (0, 0, 0)
                }

                data.append(contentsOf: [r, g, b, 255])
            }
        }

        return data
    }

    private func createTexture(from data: Data, width: Int, height: Int, device: MTLDevice) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Uint,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead]
        descriptor.storageMode = .shared

        guard let texture = device.makeTexture(descriptor: descriptor) else {
            return nil
        }

        let region = MTLRegionMake2D(0, 0, width, height)
        texture.replace(
            region: region,
            mipmapLevel: 0,
            withBytes: (data as NSData).bytes,
            bytesPerRow: width * 4
        )

        return texture
    }

    private enum TestError: Error {
        case engineInitializationFailed
        case textureCreationFailed
    }
}
