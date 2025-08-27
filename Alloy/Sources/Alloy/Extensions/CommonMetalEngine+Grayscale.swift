import Metal
import MetalKit

public extension CommonMetalEngine {
    /// Apply grayscale conversion to the current image
    /// - Parameters:
    ///   - strategy: The grayscale conversion strategy to use
    ///   - blackThreshold: Black threshold for contrast adjustment (0.0-1.0)
    ///   - whiteThreshold: White threshold for contrast adjustment (0.0-1.0)
    /// - Returns: CommonMetalEngine for chaining
    func grayscale(
        strategy: GrayscaleConversionStrategy,
        blackThreshold: Double = 0.0,
        whiteThreshold: Double = 1.0
    ) throws -> CommonMetalEngine {
        // Validate parameters
        guard blackThreshold >= 0.0, blackThreshold <= 1.0 else {
            throw MetalEngineError.generalError(message: "Black threshold must be between 0.0 and 1.0")
        }

        guard whiteThreshold >= 0.0, whiteThreshold <= 1.0 else {
            throw MetalEngineError.generalError(message: "White threshold must be between 0.0 and 1.0")
        }

        guard blackThreshold < whiteThreshold else {
            throw MetalEngineError.generalError(message: "Black threshold must be less than white threshold")
        }

        // Validate that engine has been configured with dimensions
        guard inputWidth > 0, inputHeight > 0 else {
            throw MetalEngineError.generalError(message: "Engine must be configured with input dimensions before applying grayscale. Call withRGBAData() or withRawData() first.")
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
            name: "grayscale",
            inputTexture: tempTexture,
            outputTexture: outputTexture,
            params: GrayscaleParams(
                strategy: strategy,
                blackThreshold: blackThreshold,
                whiteThreshold: whiteThreshold,
            ),
            threadgroupSize: nil,
        )

        addOperation(operation)

        return self
    }

    /// Apply black and white conversion to the current image using a threshold
    /// - Parameter threshold: Threshold value (0.0-1.0). Pixels below this value become black, above become white
    /// - Returns: CommonMetalEngine for chaining
    func blackAndWhite(threshold: Double) throws -> CommonMetalEngine {
        // Validate parameter
        guard threshold >= 0.0, threshold <= 1.0 else {
            throw MetalEngineError.generalError(message: "Threshold must be between 0.0 and 1.0")
        }

        // For black and white conversion, we use the threshold as the black level
        // and set white level just slightly above to create a sharp cutoff
        let blackThreshold = threshold
        let whiteThreshold = min(1.0, threshold + 0.001) // Small epsilon to ensure sharp transition

        return try grayscale(
            strategy: .weighted, // Use standard luminance weights for best results
            blackThreshold: blackThreshold,
            whiteThreshold: whiteThreshold,
        )
    }
}
