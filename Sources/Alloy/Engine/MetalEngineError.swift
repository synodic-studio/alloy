enum MetalEngineError: Error {
    case shaderNotFound
    case pipelineCreationFailed(Error)
    case commandBufferCreationFailed
    case textureCreationFailed
    case generalError(message: String)
}
