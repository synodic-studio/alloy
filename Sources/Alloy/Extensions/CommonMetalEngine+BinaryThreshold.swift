import Metal
import MetalKit

public extension CommonMetalEngine {
    /// Apply a hard binary threshold to the current image.
    ///
    /// Pixels with grayscale value >= `threshold` become pure white (255,255,255).
    /// All other pixels become pure black (0,0,0).
    /// There is **no ramp zone** — unlike `grayscale(blackThreshold:whiteThreshold:)`
    /// which uses a small linear interpolation zone, this operation uses a strict
    /// `>=` comparison for truly binary output.
    ///
    /// - Parameters:
    ///   - threshold: Threshold value (0.0-1.0). Pixels at or above this become white.
    ///   - strategy: Grayscale conversion strategy to use before thresholding.
    /// - Returns: CommonMetalEngine for chaining
    func binaryThreshold(
        threshold: Double,
        strategy: GrayscaleConversionStrategy = .weighted
    ) throws -> CommonMetalEngine {
        // Validate parameter
        guard threshold >= 0.0, threshold <= 1.0 else {
            throw MetalEngineError.generalError(message: "Threshold must be between 0.0 and 1.0")
        }

        // Validate that engine has been configured with dimensions
        guard inputWidth > 0, inputHeight > 0 else {
            throw MetalEngineError.generalError(
                message: "Engine must be configured with input dimensions before applying binary threshold. Call withRGBAData() or withRawData() first."
            )
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
            name: "binaryThreshold",
            inputTexture: tempTexture,
            outputTexture: outputTexture,
            params: BinaryThresholdParams(
                threshold: threshold,
                strategy: strategy,
            ),
            threadgroupSize: nil,
        )

        addOperation(operation)

        return self
    }
}
