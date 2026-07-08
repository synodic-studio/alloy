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
