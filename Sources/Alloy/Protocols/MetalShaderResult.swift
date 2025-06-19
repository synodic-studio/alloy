import Metal

/// Protocol for Metal shader results
protocol MetalShaderResult {
    var texture: MTLTexture { get }
    var width: Int { get }
    var height: Int { get }
} 