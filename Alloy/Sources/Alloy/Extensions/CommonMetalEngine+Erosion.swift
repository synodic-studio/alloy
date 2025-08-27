import Metal
import MetalKit

public extension CommonMetalEngine {
    /// Apply morphological erosion to the current image
    /// Uses configurable connectivity (4-connected or 8-connected neighbors)
    /// - Parameters:
    ///   - iterations: Number of erosion iterations to perform (1-20)
    ///   - connectivity: Connectivity type (4-connected or 8-connected)
    /// - Returns: CommonMetalEngine for chaining
    func erosion(iterations: Int = 1, connectivity: ErosionConnectivity = .eight) throws -> CommonMetalEngine {
        // TODO: Allow iterations = 0 as a no-op pass-through for UI flexibility
        // Currently requires 1-20, but 0 could be useful for disabling erosion
        // Validate parameters
        guard iterations >= 1, iterations <= 20 else {
            throw MetalEngineError.generalError(message: "Iterations must be between 1 and 20")
        }

        // Validate that engine has been configured with dimensions
        guard inputWidth > 0, inputHeight > 0 else {
            throw MetalEngineError.generalError(message: "Engine must be configured with input dimensions before applying erosion. Call withRGBAData() or withRawData() first.")
        }

        // Create output texture (same dimensions as input)
        let outputDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Uint,
            width: inputWidth,
            height: inputHeight,
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
            name: "erosion",
            inputTexture: tempTexture,
            outputTexture: outputTexture,
            params: ErosionParams(iterations: iterations, connectivity: connectivity),
            threadgroupSize: nil,
        )

        addOperation(operation)

        return self
    }
}
