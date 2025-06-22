import Metal
import MetalKit

extension CommonMetalEngine {
    
    /// Apply noise to the current image
    /// - Parameters:
    ///   - magnitude: Noise magnitude (0.0-1.0)
    ///   - seed: Random seed for reproducible results (optional)
    /// - Returns: CommonMetalEngine for chaining
    public func noise(magnitude: Double, seed: UInt32? = nil) throws -> CommonMetalEngine {
        // Validate parameters
        guard magnitude >= 0.0 && magnitude <= 1.0 else {
            throw MetalEngineError.generalError(message: "Noise magnitude must be between 0.0 and 1.0")
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
            params: NoiseParams(magnitude: magnitude, seed: seed ?? UInt32.random(in: 0...UInt32.max)),
            threadgroupSize: nil
        )
        
        addOperation(operation)
        
        return self
    }
} 