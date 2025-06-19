import Metal
import MetalKit

extension CommonMetalEngine {
    
    /// Apply a donut-shaped mask to the current image
    /// - Parameters:
    ///   - center: Center point of the donut (defaults to image center if nil)
    ///   - innerRadius: Inner radius of the donut mask
    /// - Returns: CommonMetalEngine for chaining
    public func donutMask(center: (x: Int, y: Int)? = nil, innerRadius: Int) throws -> CommonMetalEngine {
        // Use center of image if not specified
        let maskCenter = center ?? (x: inputWidth / 2, y: inputHeight / 2)
        
        // Validate parameters
        guard inputWidth == inputHeight else {
            throw MetalEngineError.generalError(message: "Input image must be square for donut mask")
        }
        
        guard maskCenter.x >= 0, maskCenter.y >= 0, maskCenter.x < inputWidth, maskCenter.y < inputHeight else {
            throw MetalEngineError.generalError(message: "Center position must be within image bounds")
        }
        
        guard innerRadius >= 0, innerRadius < inputWidth / 2 else {
            throw MetalEngineError.generalError(message: "Inner radius must be non-negative and less than half the image width")
        }
        
        // Create output texture
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
            name: "donutMask",
            inputTexture: tempTexture,
            outputTexture: outputTexture,
            params: DonutParams(
                center: SIMD2<UInt32>(UInt32(maskCenter.x), UInt32(maskCenter.y)),
                innerRadius: UInt32(innerRadius)
            ),
            threadgroupSize: nil
        )
        
        addOperation(operation)
        
        return self
    }
}
