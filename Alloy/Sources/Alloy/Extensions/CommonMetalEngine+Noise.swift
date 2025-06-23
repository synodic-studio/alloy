import Metal
import MetalKit

extension CommonMetalEngine {
    
    /// Apply noise to the current image
    /// - Parameters:
    ///   - magnitude: Noise magnitude (0.0-1.0)
    ///   - seed: Random seed for reproducible results (optional)
    ///   - ignoreBlack: If true, purely black pixels (RGB: 0,0,0) will not have noise applied
    ///   - ignoreWhite: If true, purely white pixels (RGB: 255,255,255) will not have noise applied
    /// - Returns: CommonMetalEngine for chaining
    public func noise(
        magnitude: Double, 
        seed: UInt32? = nil,
        ignoreBlack: Bool = false,
        ignoreWhite: Bool = false
    ) throws -> CommonMetalEngine {
        // Validate parameters
        guard magnitude >= 0.0 && magnitude <= 1.0 else {
            throw MetalEngineError.generalError(message: "Noise magnitude must be between 0.0 and 1.0")
        }
        
        // Validate that engine has been configured with dimensions
        guard inputWidth > 0 && inputHeight > 0 else {
            throw MetalEngineError.generalError(message: "Engine must be configured with input dimensions before applying noise. Call withRGBAData() or withRawData() first.")
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
            name: "noise",
            inputTexture: tempTexture,
            outputTexture: outputTexture,
            params: NoiseParams(
                magnitude: magnitude, 
                seed: seed ?? UInt32.random(in: 0...UInt32.max),
                ignoreBlack: ignoreBlack,
                ignoreWhite: ignoreWhite
            ),
            threadgroupSize: nil
        )
        
        addOperation(operation)
        
        return self
    }
} 