import Metal
import MetalKit

public extension CommonMetalEngine {
    /// Apply RGGB pattern debayering to raw sensor data
    /// - Parameter bitDepth: Bit depth of the raw data (8 or 16)
    /// - Returns: CommonMetalEngine for chaining
    func debayerRGGB(bitDepth: Int? = nil) throws -> CommonMetalEngine {
        // Use provided bitDepth or fall back to configured bit depth
        let actualBitDepth = bitDepth ?? inputBitDepth

        // Calculate output dimensions (half size for debayering)
        let outputWidth = inputWidth / 2
        let outputHeight = inputHeight / 2

        // Create output texture
        let outputDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Uint,
            width: outputWidth,
            height: outputHeight,
            mipmapped: false,
        )
        outputDescriptor.usage = [.shaderWrite, .shaderRead]
        outputDescriptor.storageMode = .shared

        guard let outputTexture = device.makeTexture(descriptor: outputDescriptor) else {
            throw MetalEngineError.textureCreationFailed
        }

        // Create a temporary input texture (will be replaced during execution)
        let tempDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r8Uint,
            width: 1,
            height: 1,
            mipmapped: false,
        )
        guard let tempTexture = device.makeTexture(descriptor: tempDescriptor) else {
            throw MetalEngineError.textureCreationFailed
        }

        // Create operation
        let operation = TypedShaderOperation(
            name: "debayerKernelRGGB",
            inputTexture: tempTexture,
            outputTexture: outputTexture,
            params: DebayerParams(bitDepth: UInt32(actualBitDepth)),
            threadgroupSize: nil,
        )

        addOperation(operation)

        return self
    }
}
