import Metal
import MetalKit

extension CommonMetalEngine {
    
    /// Apply image inversion to the current image
    /// Inverts the RGB channels while preserving the alpha channel
    /// - Returns: CommonMetalEngine for chaining
    public func invert() throws -> CommonMetalEngine {
        // Validate that engine has been configured with dimensions
        guard inputWidth > 0 && inputHeight > 0 else {
            throw MetalEngineError.generalError(message: "Engine must be configured with input dimensions before applying invert. Call withRGBAData() or withRawData() first.")
        }
        
        // Create output texture with same dimensions as input
        let outputDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Uint,
            width: inputWidth,
            height: inputHeight,
            mipmapped: false
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
            mipmapped: false
        )
        guard let tempTexture = device.makeTexture(descriptor: tempDescriptor) else {
            throw MetalEngineError.textureCreationFailed
        }
        
        // Create operation
        let operation = TypedShaderOperation(
            name: "invert",
            inputTexture: tempTexture,
            outputTexture: outputTexture,
            params: InvertParams(),
            threadgroupSize: nil
        )
        
        addOperation(operation)
        
        return self
    }
} 