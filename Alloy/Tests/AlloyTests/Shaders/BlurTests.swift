import Testing
import AppKit
import Metal

@testable import Alloy

@Suite("Blur Shader Computation Tests")
struct BlurTests {

    // MARK: - Basic Functionality Tests

    @Test("Blur applies without error")
    func testBlurBasicFunctionality() throws {
        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }
        
        let inputColor = NSColor.red
        let data = self.data(from: inputColor)
        
        let result = try engine
            .withRGBAData(width: 1, height: 1)
            .blur(radius: 2.0)
            .execute(data: data)

        let outputPixels = try pixels(from: result.texture)
        #expect(outputPixels.count == 1)
        
        // For a single pixel, blur should essentially return the same pixel
        let expectedPixel = Pixel(r: inputColor)
        #expect(
            outputPixels.first?.isApproximatelyEqual(to: expectedPixel, tolerance: 5) == true,
            "Single pixel blur should return approximately the same pixel"
        )
    }

    @Test("Blur preserves average intensity in uniform regions")
    func testBlurPreservesAverageIntensity() throws {
        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }
        
        // Create a 3x3 uniform red image
        let uniformColor = NSColor.red
        let width = 3
        let height = 3
        var data = Data()
        
        for _ in 0..<(width * height) {
            data.append(contentsOf: self.data(from: uniformColor))
        }
        
        let result = try engine
            .withRGBAData(width: width, height: height)
            .blur(radius: 1.0)
            .execute(data: data)

        let outputPixels = try pixels(from: result.texture)
        
        // All pixels should remain approximately the same in a uniform region
        for pixel in outputPixels {
            let expectedPixel = Pixel(r: uniformColor)
            #expect(
                pixel.isApproximatelyEqual(to: expectedPixel, tolerance: 10),
                "Uniform region should maintain color after blur"
            )
        }
    }

    @Test("Blur smooths sharp edges")
    func testBlurSmoothsEdges() throws {
        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }
        
        // Create a 3x3 image with sharp transition (black-white-black pattern)
        let data = Data([
            0, 0, 0, 255,     255, 255, 255, 255,   0, 0, 0, 255,     // Top row
            0, 0, 0, 255,     255, 255, 255, 255,   0, 0, 0, 255,     // Middle row
            0, 0, 0, 255,     255, 255, 255, 255,   0, 0, 0, 255      // Bottom row
        ])
        
        let result = try engine
            .withRGBAData(width: 3, height: 3)
            .blur(radius: 1.0)
            .execute(data: data)

        let outputPixels = try pixels(from: result.texture)
        
        // The center pixel should remain mostly white but the edge pixels should be grayed
        let centerPixel = outputPixels[4] // Center of 3x3 grid
        let edgePixel = outputPixels[0]   // Corner pixel
        
        #expect(centerPixel.r > 195, "Center pixel should remain bright")
        #expect(edgePixel.r > 30, "Edge pixels should be brighter than original black")
        #expect(edgePixel.r < 200, "Edge pixels should be darker than original white")
    }

    // MARK: - Parameter Validation Tests

    @Test("Blur validation throws for zero radius")
    func testBlurValidationZeroRadius() throws {
        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }
        
        #expect(throws: MetalEngineError.self) {
            try engine.blur(radius: 0.0)
        }
    }

    @Test("Blur validation throws for negative radius")
    func testBlurValidationNegativeRadius() throws {
        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }
        
        #expect(throws: MetalEngineError.self) {
            try engine.blur(radius: -1.0)
        }
    }

    @Test("Blur accepts valid small radius")
    func testBlurValidSmallRadius() throws {
        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }
        
        // Should not throw
        let _ = try engine
            .withRGBAData(width: 1, height: 1)
            .blur(radius: 0.1)
    }

    @Test("Blur accepts valid large radius")
    func testBlurValidLargeRadius() throws {
        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }
        
        // Should not throw
        let _ = try engine
            .withRGBAData(width: 1, height: 1)
            .blur(radius: 50.0)
    }

    // MARK: - Different Radius Effects Tests

    @Test("Larger radius produces more blur")
    func testLargerRadiusProducesMoreBlur() throws {
        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }
        
        // Create a 5x5 image with white center and black edges
        let size = 5
        var data = Data()
        
        for y in 0..<size {
            for x in 0..<size {
                if x == 2 && y == 2 {
                    // Center pixel - white
                    data.append(contentsOf: [255, 255, 255, 255])
                } else {
                    // Edge pixels - black
                    data.append(contentsOf: [0, 0, 0, 255])
                }
            }
        }
        
        // Test with small radius
        let resultSmall = try engine
            .withRGBAData(width: size, height: size)
            .blur(radius: 0.5)
            .execute(data: data)
        
        // Test with large radius
        let resultLarge = try engine
            .withRGBAData(width: size, height: size)
            .blur(radius: 2.0)
            .execute(data: data)
        
        let pixelsSmall = try pixels(from: resultSmall.texture)
        let pixelsLarge = try pixels(from: resultLarge.texture)
        
        // Check pixels adjacent to center - they should be brighter with larger radius  
        let adjacentIndexSmall = pixelsSmall[7].r  // Pixel at (2,1) - above center
        let adjacentIndexLarge = pixelsLarge[7].r  // Same pixel with larger radius
        
        #expect(
            adjacentIndexLarge > adjacentIndexSmall,
            "Larger blur radius should affect adjacent pixels more"
        )
    }

    // MARK: - Alpha Channel Tests

    @Test("Blur preserves alpha channel")
    func testBlurPreservesAlpha() throws {
        guard let engine = CommonMetalEngine() else { throw TestError.engineInitializationFailed }
        
        let inputColor = NSColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 0.5)
        let data = self.data(from: inputColor)
        
        let result = try engine
            .withRGBAData(width: 1, height: 1)
            .blur(radius: 1.0)
            .execute(data: data)

        let outputPixels = try pixels(from: result.texture)
        #expect(outputPixels.count == 1)
        
        if let pixel = outputPixels.first {
            #expect(
                pixel.a == 127,  // 0.5 * 255 = 127.5, truncated to 127 by UInt8 conversion
                "Alpha channel should be preserved"
            )
        }
    }

    // MARK: - Helper Methods
    
    private func data(from color: NSColor) -> Data {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        // Convert to RGB colorspace if needed to avoid colorspace conversion errors
        let rgbColor = color.usingColorSpace(.deviceRGB) ?? color
        rgbColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        return Data([
            UInt8(r * 255),
            UInt8(g * 255),
            UInt8(b * 255),
            UInt8(a * 255)
        ])
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

    init(r: NSColor) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        // Convert to RGB colorspace if needed to avoid colorspace conversion errors
        let rgbColor = r.usingColorSpace(.deviceRGB) ?? r
        rgbColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        self.r = UInt8(red * 255)
        self.g = UInt8(green * 255)
        self.b = UInt8(blue * 255)
        self.a = UInt8(alpha * 255)
    }

    func isApproximatelyEqual(to other: Pixel, tolerance: Int = 1) -> Bool {
        return abs(Int(self.r) - Int(other.r)) <= tolerance &&
        abs(Int(self.g) - Int(other.g)) <= tolerance &&
        abs(Int(self.b) - Int(other.b)) <= tolerance &&
        abs(Int(self.a) - Int(other.a)) <= tolerance
    }
} 