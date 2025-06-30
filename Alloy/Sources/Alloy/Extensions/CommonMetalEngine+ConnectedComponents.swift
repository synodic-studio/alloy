import Metal
import MetalKit

extension CommonMetalEngine {
    
    /// Apply connected components analysis to the current binary image
    /// This analyzes white pixel groups for finding centroids later
    /// - Parameters:
    ///   - maxComponents: Maximum number of components to detect (default: 1000)
    ///   - maxPixelsPerBlob: Maximum pixels per blob - larger blobs are ignored (default: 100)
    /// - Returns: CommonMetalEngine for chaining
    public func connectedComponents(maxComponents: Int = 50, maxPixelsPerBlob: Int = 100) throws -> CommonMetalEngine {
        // Validate parameters
        guard maxComponents > 0 && maxComponents <= 10000 else {
            throw MetalEngineError.generalError(message: "maxComponents must be between 1 and 10000")
        }
        
        guard maxPixelsPerBlob > 0 && maxPixelsPerBlob <= 1000 else {
            throw MetalEngineError.generalError(message: "maxPixelsPerBlob must be between 1 and 1000")
        }
        
        // Validate that engine has been configured with dimensions
        guard inputWidth > 0 && inputHeight > 0 else {
            throw MetalEngineError.generalError(message: "Engine must be configured with input dimensions before applying connected components. Call withRGBAData() or withRawData() first.")
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
            name: "connectedComponents",
            inputTexture: tempTexture,
            outputTexture: outputTexture,
            params: ConnectedComponentsParams(maxComponents: maxComponents, maxPixelsPerBlob: maxPixelsPerBlob),
            threadgroupSize: nil
        )
        
        addOperation(operation)
        
        return self
    }
    
    /// Execute connected components analysis and return both texture and centroid data
    /// This is a direct method that bypasses the standard pipeline for special buffer operations
    /// - Parameters:
    ///   - data: Input RGBA data
    ///   - maxComponents: Maximum number of components to detect  
    ///   - maxPixelsPerBlob: Maximum pixels per blob
    /// - Returns: ConnectedComponentsResult containing processed texture and detected centroids
    public func executeConnectedComponents(data: Data, maxComponents: Int = 50, maxPixelsPerBlob: Int = 100) throws -> ConnectedComponentsResult {
        // Validate that engine has been configured with dimensions
        guard inputWidth > 0 && inputHeight > 0 else {
            throw MetalEngineError.generalError(message: "Engine must be configured with input dimensions.")
        }
        
        // Create input texture from data
        let inputDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Uint,
            width: inputWidth,
            height: inputHeight,
            mipmapped: false
        )
        inputDescriptor.usage = .shaderRead
        inputDescriptor.storageMode = .shared
        
        guard let inputTexture = device.makeTexture(descriptor: inputDescriptor) else {
            throw MetalEngineError.textureCreationFailed
        }
        
        // Copy data to input texture
        let region = MTLRegionMake2D(0, 0, inputWidth, inputHeight)
        inputTexture.replace(
            region: region,
            mipmapLevel: 0,
            withBytes: (data as NSData).bytes,
            bytesPerRow: inputWidth * 4
        )
        
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
        
        // Create buffers for component data
        let componentBufferLength = maxComponents * MemoryLayout<ComponentData>.size
        guard let componentBuffer = device.makeBuffer(
            length: componentBufferLength,
            options: .storageModeShared
        ) else {
            throw MetalEngineError.generalError(message: "Failed to create component buffer")
        }
        
        // Create buffer for component count
        guard let countBuffer = device.makeBuffer(
            length: MemoryLayout<UInt32>.size,
            options: .storageModeShared
        ) else {
            throw MetalEngineError.generalError(message: "Failed to create count buffer")
        }
        
        // Initialize count to 0
        let countPointer = countBuffer.contents().bindMemory(to: UInt32.self, capacity: 1)
        countPointer[0] = 0
        
        // Execute the connected components shader with buffers
        try executeConnectedComponentsShader(
            inputTexture: inputTexture,
            outputTexture: outputTexture,
            componentBuffer: componentBuffer,
            countBuffer: countBuffer,
            maxComponents: maxComponents,
            maxPixelsPerBlob: maxPixelsPerBlob
        )
        
        // Read back results
        let detectedCount = Int(countPointer[0])
        var centroids: [ComponentCentroid] = []
        
        if detectedCount > 0 {
            let componentPointer = componentBuffer.contents().bindMemory(
                to: ComponentData.self,
                capacity: maxComponents
            )
            
            for i in 0..<min(detectedCount, maxComponents) {
                let componentData = componentPointer[i]
                let centroid = ComponentCentroid(
                    x: componentData.centroidX,
                    y: componentData.centroidY,
                    pixelCount: componentData.pixelCount
                )
                centroids.append(centroid)
            }
        }
        
        return ConnectedComponentsResult(
            texture: outputTexture,
            width: inputWidth,
            height: inputHeight,
            centroids: centroids
        )
    }
    
    // MARK: - Private Methods
    
    private func executeConnectedComponentsShader(
        inputTexture: MTLTexture,
        outputTexture: MTLTexture,
        componentBuffer: MTLBuffer,
        countBuffer: MTLBuffer,
        maxComponents: Int,
        maxPixelsPerBlob: Int
    ) throws {
        // Initialize the pipeline state
        let pipelineState = try initializePipeline(name: "connectedComponents")
        
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw MetalEngineError.commandBufferCreationFailed
        }
        
        // Configure compute encoder
        computeEncoder.setComputePipelineState(pipelineState)
        computeEncoder.setTexture(inputTexture, index: 0)
        computeEncoder.setTexture(outputTexture, index: 1)
        computeEncoder.setBuffer(componentBuffer, offset: 0, index: 1)
        computeEncoder.setBuffer(countBuffer, offset: 0, index: 2)
        
        // Set shader parameters
        let params = ConnectedComponentsParams(maxComponents: maxComponents, maxPixelsPerBlob: maxPixelsPerBlob)
        withUnsafeBytes(of: params) { rawBufferPointer in
            computeEncoder.setBytes(
                rawBufferPointer.baseAddress!,
                length: MemoryLayout<ConnectedComponentsParams>.size,
                index: 0
            )
        }
        
        // Calculate threadgroup sizes
        let threadgroupSize = calculateOptimalThreadgroupSize(
            pipelineState: pipelineState,
            outputWidth: outputTexture.width,
            outputHeight: outputTexture.height
        )
        
        let threadgroupCount = MTLSize(
            width: (outputTexture.width + threadgroupSize.width - 1) / threadgroupSize.width,
            height: (outputTexture.height + threadgroupSize.height - 1) / threadgroupSize.height,
            depth: 1
        )
        
        // Dispatch work
        computeEncoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
        computeEncoder.endEncoding()
        
        // Execute and wait for completion
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
} 
