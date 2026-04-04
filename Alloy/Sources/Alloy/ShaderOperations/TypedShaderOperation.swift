import Metal

/// Concrete implementation of ShaderOperation for specific parameter types
struct TypedShaderOperation<P: MetalShaderParameters & Sendable>: ShaderOperation {
    let name: String
    var inputTexture: MTLTexture
    let outputTexture: MTLTexture
    let params: P
    let threadgroupSize: MTLSize?

    func setParameters(encoder: MTLComputeCommandEncoder) {
        withUnsafePointer(to: params) { pointer in
            encoder.setBytes(
                pointer,
                length: MemoryLayout<P>.size,
                index: params.bufferIndex,
            )
        }
    }
}
