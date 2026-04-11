import Metal

/// Protocol for Metal shader results
public protocol MetalShaderResult {
    var texture: MTLTexture { get }
    var width: Int { get }
    var height: Int { get }
}
