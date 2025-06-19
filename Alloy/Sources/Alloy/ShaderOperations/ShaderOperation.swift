import Metal

/// A shader operation to be executed as part of a chain
protocol ShaderOperation {
    var name: String { get }
    var inputTexture: MTLTexture { get set }
    var outputTexture: MTLTexture { get }
    var threadgroupSize: MTLSize? { get }
    func setParameters(encoder: MTLComputeCommandEncoder)
} 