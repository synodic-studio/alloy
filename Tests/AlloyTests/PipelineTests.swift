import CoreGraphics
import Foundation
import Metal
import Testing

@testable import Alloy

@Suite("Pipeline Type-Safe Frontend")
struct PipelineTests {
    /// The typed frontend must only add types, never change behaviour: a
    /// `Pipeline` chain produces byte-identical output to the equivalent raw
    /// `CommonMetalEngine` chain.
    @Test("blackAndWhite→erosion matches raw engine byte-for-byte")
    func matchesRawEngine() throws {
        let width = 256
        let height = 256
        let data = Self.makeRGBAData(width: width, height: height)
        let threshold = 0.5
        let iterations = 2

        let typed = try Pipeline.rgba(width: width, height: height)
            .blackAndWhite(threshold: threshold)
            .erosion(iterations: iterations)
            .run(on: data)

        guard let engine = CommonMetalEngine() else {
            throw MetalEngineError.generalError(message: "Failed to create Metal engine")
        }
        let raw = try engine
            .withRGBAData(width: width, height: height)
            .blackAndWhite(threshold: threshold)
            .erosion(iterations: iterations)
            .execute(data: data)

        #expect(typed.width == raw.width)
        #expect(typed.height == raw.height)
        #expect(typed.data == raw.data)
    }

    /// The terminal `connectedComponents` is offered only on `Pipeline<Binary>`
    /// and respects the upstream erosion by executing the recorded chain first.
    @Test("connectedComponents terminal detects a blob on the binary state")
    func connectedComponentsTerminal() throws {
        let width = 256
        let height = 256
        let data = Self.makeBlobData(width: width, height: height)

        let result = try Pipeline.rgba(width: width, height: height)
            .blackAndWhite(threshold: 0.3)
            .erosion(iterations: 1)
            .connectedComponents(on: data, maxComponents: 20)

        #expect(result.width == width)
        #expect(result.height == height)
        #expect(result.centroids.count >= 1)
    }

    /// A full raw pipeline — raw Bayer through debayer, geometric ops, and
    /// grayscale — must match the equivalent raw `CommonMetalEngine` chain
    /// byte-for-byte.
    @Test("raw → debayer → crop → donutMask → grayscale matches raw engine")
    func rawChainMatchesRawEngine() throws {
        let width = 256
        let height = 256
        let data = Self.makeRawData(width: width, height: height)

        let typed = try Pipeline.rawBayer(width: width, height: height, bitDepth: 8)
            .debayerRGGB()
            .squareCrop(center: (x: 128, y: 128), sideLength: 200)
            .donutMask(innerRadius: 50)
            .grayscale(strategy: .weighted)
            .run(on: data)

        guard let engine = CommonMetalEngine() else {
            throw MetalEngineError.generalError(message: "Failed to create Metal engine")
        }
        let raw = try engine
            .withRawData(width: width, height: height, bitDepth: 8)
            .debayerRGGB()
            .squareCrop(center: (x: 128, y: 128), sideLength: 200)
            .donutMask(innerRadius: 50)
            .grayscale(strategy: .weighted)
            .execute(data: data)

        #expect(typed.width == raw.width)
        #expect(typed.height == raw.height)
        #expect(typed.data == raw.data)
    }

    /// The `peakDetection` terminal is offered on `Grayscale` and returns the
    /// marked visualization image at the pipeline's dimensions.
    @Test("peakDetection terminal runs on the grayscale state")
    func peakDetectionTerminal() throws {
        let width = 256
        let height = 256
        let data = Self.makeRGBAData(width: width, height: height)

        let result = try Pipeline.rgba(width: width, height: height)
            .grayscale(strategy: .maxChannelRG)
            .peakDetection(on: data, neighborhoodSize: 3, threshold: 0.5)

        #expect(result.width == width)
        #expect(result.height == height)
    }

    /// Blur on the grayscale state preserves it and matches the raw engine
    /// byte-for-byte.
    @Test("grayscale blur matches raw engine and stays grayscale")
    func grayscaleBlurMatchesRawEngine() throws {
        let width = 256
        let height = 256
        let data = Self.makeRGBAData(width: width, height: height)

        let typed = try Pipeline.rgba(width: width, height: height)
            .grayscale(strategy: .weighted)
            .blur(radius: 2)
            .run(on: data)

        guard let engine = CommonMetalEngine() else {
            throw MetalEngineError.generalError(message: "Failed to create Metal engine")
        }
        let raw = try engine
            .withRGBAData(width: width, height: height)
            .grayscale(strategy: .weighted)
            .blur(radius: 2)
            .execute(data: data)

        #expect(typed.data == raw.data)
    }

    /// The colour-sampling terminal returns one colour per requested position.
    @Test("sampleColors terminal returns a colour per position")
    func colorSamplingTerminal() throws {
        let width = 256
        let height = 256
        let data = Self.makeRGBAData(width: width, height: height)
        let positions = [CGPoint(x: 10, y: 10), CGPoint(x: 128, y: 128), CGPoint(x: 200, y: 50)]

        let result = try Pipeline.rgba(width: width, height: height)
            .sampleColors(on: data, at: positions, radius: 3.0)

        #expect(result.colors.count == positions.count)
        #expect(result.positions.count == positions.count)
    }

    // MARK: - Fixtures

    private static func makeRGBAData(width: Int, height: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        for i in 0 ..< width * height {
            let v: UInt8 = (i % 7 == 0) ? 255 : 40 // sparse bright pixels
            bytes[i * 4] = v
            bytes[i * 4 + 1] = v
            bytes[i * 4 + 2] = v
            bytes[i * 4 + 3] = 255
        }
        return Data(bytes)
    }

    private static func makeRawData(width: Int, height: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: width * height) // 8-bit single channel
        for i in 0 ..< width * height {
            bytes[i] = UInt8((i * 7) % 256)
        }
        return Data(bytes)
    }

    private static func makeBlobData(width: Int, height: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let cx = width / 2
        let cy = height / 2
        let r = 6
        for y in 0 ..< height {
            for x in 0 ..< width where (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r {
                let idx = (y * width + x) * 4
                bytes[idx] = 255
                bytes[idx + 1] = 255
                bytes[idx + 2] = 255
                bytes[idx + 3] = 255
            }
        }
        return Data(bytes)
    }
}
