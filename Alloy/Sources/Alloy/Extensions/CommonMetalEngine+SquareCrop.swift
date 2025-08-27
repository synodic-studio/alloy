import Metal
import MetalKit

public extension CommonMetalEngine {
    /// Apply square crop to the current image
    /// - Parameters:
    ///   - center: Center point of the crop (x, y)
    ///   - sideLength: Side length of the square crop
    /// - Returns: CommonMetalEngine for chaining
    func squareCrop(center: (x: Int, y: Int), sideLength: Int) throws -> CommonMetalEngine {
        // Validate parameters
        guard sideLength > 0 else {
            throw MetalEngineError.generalError(message: "Side length must be greater than 0")
        }

        // Create output texture
        let outputDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Uint,
            width: sideLength,
            height: sideLength,
            mipmapped: false,
        )
        outputDescriptor.usage = [.shaderWrite, .shaderRead]
        outputDescriptor.storageMode = .shared

        guard let outputTexture = device.makeTexture(descriptor: outputDescriptor) else {
            throw MetalEngineError.textureCreationFailed
        }

        // Create a temporary input texture (will be replaced during execution)
        let tempDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Uint,
            width: 1,
            height: 1,
            mipmapped: false,
        )
        guard let tempTexture = device.makeTexture(descriptor: tempDescriptor) else {
            throw MetalEngineError.textureCreationFailed
        }

        // Create operation
        let operation = TypedShaderOperation(
            name: "squareCrop",
            inputTexture: tempTexture,
            outputTexture: outputTexture,
            params: MetalSquareCropParams(
                center: SIMD2<UInt32>(UInt32(center.x), UInt32(center.y)),
                sideLength: UInt32(sideLength),
            ),
            threadgroupSize: nil,
        )

        addOperation(operation)

        return self
    }
}
