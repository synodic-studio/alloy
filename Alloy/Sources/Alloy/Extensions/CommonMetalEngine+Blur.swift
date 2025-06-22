import Metal
import MetalKit

extension CommonMetalEngine {
    
    /// Apply blur to the current image using 1/r² weighting
    /// - Parameter radius: Blur radius in pixels (must be > 0)
    /// - Returns: CommonMetalEngine for chaining
    public func blur(radius: Double) throws -> CommonMetalEngine {
        // Validate parameters
        guard radius > 0 else {
            throw MetalEngineError.generalError(message: "Blur radius must be greater than 0")
        }
        
        // Validate that engine has been configured with dimensions
        guard inputWidth > 0 && inputHeight > 0 else {
            throw MetalEngineError.generalError(message: "Engine must be configured with input dimensions before applying blur. Call withRGBAData() or withRawData() first.")
        }
        
        // Create output texture (same dimensions as input)
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
            name: "blur",
            inputTexture: tempTexture,
            outputTexture: outputTexture,
            params: BlurParams(radius: radius),
            threadgroupSize: nil
        )
        
        addOperation(operation)
        
        return self
    }
} 