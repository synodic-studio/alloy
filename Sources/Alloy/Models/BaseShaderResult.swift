import Metal

/// Base implementation for shader results with common functionality
struct BaseShaderResult: MetalShaderResult {
    let texture: MTLTexture
    let width: Int
    let height: Int
} 