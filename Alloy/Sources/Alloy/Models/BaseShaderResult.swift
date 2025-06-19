import Metal

/// Base implementation for shader results with common functionality
public struct BaseShaderResult: MetalShaderResult {
    public let texture: MTLTexture
    public let width: Int
    public let height: Int
} 
