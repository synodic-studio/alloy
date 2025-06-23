import Metal
import MetalKit

extension CommonMetalEngine {
    
    /// Apply peak detection to the current image and return coordinates
    /// - Parameters:
    ///   - data: Input image data
    ///   - neighborhoodSize: Number of neighbors to check (8 or 16, default: 8)
    ///   - minDistance: Minimum distance between peaks (default: 5.0)
    ///   - maxPeaks: Maximum number of peaks to detect (default: 100)
    ///   - threshold: Minimum intensity threshold for peak detection (0.0-1.0, default: 0.5)
    /// - Returns: Array of detected peak coordinates
    public func detectPeaks(
        data: Data,
        neighborhoodSize: Int = 8,
        minDistance: Double = 5.0,
        maxPeaks: Int = 100,
        threshold: Double = 0.5
    ) throws -> [DetectedPeak] {
        // Validate parameters
        guard neighborhoodSize == 8 || neighborhoodSize == 16 else {
            throw MetalEngineError.generalError(message: "Neighborhood size must be 8 or 16")
        }
        
        guard minDistance > 0 else {
            throw MetalEngineError.generalError(message: "Minimum distance must be greater than 0")
        }
        
        guard maxPeaks > 0 else {
            throw MetalEngineError.generalError(message: "maxPeaks must be greater than 0")
        }
        
        guard threshold >= 0.0 && threshold <= 1.0 else {
            throw MetalEngineError.generalError(message: "Threshold must be between 0.0 and 1.0")
        }
        
        // Validate that engine has been configured with dimensions
        guard inputWidth > 0 && inputHeight > 0 else {
            throw MetalEngineError.generalError(message: "Engine must be configured with input dimensions before peak detection. Call withRGBAData() or withRawData() first.")
        }
        
        // Create input texture directly from data
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
            bytesPerRow: inputWidth * 4 // 4 bytes per RGBA pixel
        )
        
        // Create buffer for detected peaks
        let peakBufferLength = maxPeaks * MemoryLayout<DetectedPeakData>.size
        guard let peakBuffer = device.makeBuffer(length: peakBufferLength, options: .storageModeShared) else {
            throw MetalEngineError.generalError(message: "Failed to create peak buffer")
        }
        
        // Create buffer for peak count
        guard let countBuffer = device.makeBuffer(length: MemoryLayout<UInt32>.size, options: .storageModeShared) else {
            throw MetalEngineError.generalError(message: "Failed to create count buffer")
        }
        
        // Initialize count to 0
        let countPointer = countBuffer.contents().bindMemory(to: UInt32.self, capacity: 1)
        countPointer[0] = 0
        
        // Create a temporary output texture (not used for coordinates, but required by shader)
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
        
        // Execute peak detection shader
        try executePeakDetectionShader(
            inputTexture: inputTexture,
            outputTexture: outputTexture,
            peakBuffer: peakBuffer,
            countBuffer: countBuffer,
            params: PeakDetectionParams(
                neighborhoodSize: neighborhoodSize,
                minDistance: minDistance,
                maxPeaks: maxPeaks,
                threshold: threshold
            )
        )
        
        // Read back the detected peaks
        let detectedCount = Int(countPointer[0])
        var detectedPeaks: [DetectedPeak] = []
        
        if detectedCount > 0 {
            let peakDataPointer = peakBuffer.contents().bindMemory(to: DetectedPeakData.self, capacity: maxPeaks)
            
            for i in 0..<min(detectedCount, maxPeaks) {
                let peakData = peakDataPointer[i]
                let peak = DetectedPeak(
                    x: peakData.x,
                    y: peakData.y,
                    value: peakData.value
                )
                detectedPeaks.append(peak)
            }
        }
        
        // Apply distance-based filtering to remove close peaks
        detectedPeaks = filterPeaksByDistance(peaks: detectedPeaks, minDistance: Float(minDistance))
        
        return detectedPeaks
    }
    
    /// Apply peak detection to the current image (visualization only)
    /// - Parameter neighborhoodSize: Number of neighbors to check (8 or 16, default: 8)
    /// - Returns: CommonMetalEngine for chaining
    public func peakDetection(
        neighborhoodSize: Int = 8,
        threshold: Double = 0.5
    ) throws -> CommonMetalEngine {
        // Validate parameters
        guard neighborhoodSize == 8 || neighborhoodSize == 16 else {
            throw MetalEngineError.generalError(message: "Neighborhood size must be 8 or 16")
        }
        
        guard threshold >= 0.0 && threshold <= 1.0 else {
            throw MetalEngineError.generalError(message: "Threshold must be between 0.0 and 1.0")
        }
        
        // Validate that engine has been configured with dimensions
        guard inputWidth > 0 && inputHeight > 0 else {
            throw MetalEngineError.generalError(message: "Engine must be configured with input dimensions before peak detection. Call withRGBAData() or withRawData() first.")
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
            name: "peakDetection",
            inputTexture: tempTexture,
            outputTexture: outputTexture,
            params: PeakDetectionParams(
                neighborhoodSize: neighborhoodSize,
                minDistance: 1.0,  // Not used in simple version
                maxPeaks: 100,     // Not used in simple version
                threshold: threshold
            ),
            threadgroupSize: nil
        )
        
        addOperation(operation)
        
        return self
    }
    
    /// Apply peak detection to the current image and return both regular result and detected peaks
    /// - Parameters:
    ///   - data: Input image data
    ///   - neighborhoodSize: Number of neighbors to check (8 or 16, default: 8)
    ///   - minDistance: Minimum distance between peaks (default: 5.0)
    ///   - maxPeaks: Maximum number of peaks to detect (default: 100)
    ///   - threshold: Minimum intensity threshold for peak detection (0.0-1.0, default: 0.5)
    /// - Returns: PeakDetectionResult containing detected peaks and processed texture
    public func executeWithPeakDetection(
        data: Data,
        neighborhoodSize: Int = 8,
        minDistance: Double = 5.0,
        maxPeaks: Int = 100,
        threshold: Double = 0.5
    ) throws -> PeakDetectionResult {
        // Validate parameters
        guard neighborhoodSize == 8 || neighborhoodSize == 16 else {
            throw MetalEngineError.generalError(message: "Neighborhood size must be 8 or 16")
        }
        
        guard minDistance > 0 else {
            throw MetalEngineError.generalError(message: "Minimum distance must be greater than 0")
        }
        
        guard threshold >= 0.0 && threshold <= 1.0 else {
            throw MetalEngineError.generalError(message: "Threshold must be between 0.0 and 1.0")
        }
        
        guard maxPeaks > 0 else {
            throw MetalEngineError.generalError(message: "maxPeaks must be greater than 0")
        }
        
        // Execute existing operations if any, otherwise work directly with input data
        let intermediateResult: BaseShaderResult
        if hasOperations {
            intermediateResult = try execute(data: data)
        } else {
            // No operations to execute, create input texture directly
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
                bytesPerRow: inputWidth * 4 // 4 bytes per RGBA pixel
            )
            
            intermediateResult = BaseShaderResult(
                texture: inputTexture,
                width: inputWidth,
                height: inputHeight
            )
        }
        
        // Create output texture for peak visualization
        let outputDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Uint,
            width: intermediateResult.width,
            height: intermediateResult.height,
            mipmapped: false
        )
        outputDescriptor.usage = [.shaderWrite, .shaderRead]
        outputDescriptor.storageMode = .shared
        
        guard let outputTexture = device.makeTexture(descriptor: outputDescriptor) else {
            throw MetalEngineError.textureCreationFailed
        }
        
        // Create buffer for detected peaks
        let peakBufferLength = maxPeaks * MemoryLayout<DetectedPeakData>.size
        guard let peakBuffer = device.makeBuffer(length: peakBufferLength, options: .storageModeShared) else {
            throw MetalEngineError.generalError(message: "Failed to create peak buffer")
        }
        
        // Create buffer for peak count
        guard let countBuffer = device.makeBuffer(length: MemoryLayout<UInt32>.size, options: .storageModeShared) else {
            throw MetalEngineError.generalError(message: "Failed to create count buffer")
        }
        
        // Initialize count to 0
        let countPointer = countBuffer.contents().bindMemory(to: UInt32.self, capacity: 1)
        countPointer[0] = 0
        
        // Execute peak detection shader
        try executePeakDetectionShader(
            inputTexture: intermediateResult.texture,
            outputTexture: outputTexture,
            peakBuffer: peakBuffer,
            countBuffer: countBuffer,
            params: PeakDetectionParams(
                neighborhoodSize: neighborhoodSize,
                minDistance: minDistance,
                maxPeaks: maxPeaks,
                threshold: threshold
            )
        )
        
        // Read back the detected peaks
        let detectedCount = Int(countPointer[0])
        var detectedPeaks: [DetectedPeak] = []
        
        if detectedCount > 0 {
            let peakDataPointer = peakBuffer.contents().bindMemory(to: DetectedPeakData.self, capacity: maxPeaks)
            
            for i in 0..<min(detectedCount, maxPeaks) {
                let peakData = peakDataPointer[i]
                let peak = DetectedPeak(
                    x: peakData.x,
                    y: peakData.y,
                    value: peakData.value
                )
                detectedPeaks.append(peak)
            }
        }
        
        // Apply distance-based filtering to remove close peaks
        detectedPeaks = filterPeaksByDistance(peaks: detectedPeaks, minDistance: Float(minDistance))
        
        return PeakDetectionResult(
            texture: outputTexture,
            width: intermediateResult.width,
            height: intermediateResult.height,
            detectedPeaks: detectedPeaks
        )
    }
    
    // MARK: - Private Helper Methods
    
    private func executePeakDetectionShader(
        inputTexture: MTLTexture,
        outputTexture: MTLTexture,
        peakBuffer: MTLBuffer,
        countBuffer: MTLBuffer,
        params: PeakDetectionParams
    ) throws {
        let pipelineState = try initializePipeline(name: "peakDetection")
        
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw MetalEngineError.commandBufferCreationFailed
        }
        
        // Configure compute encoder
        computeEncoder.setComputePipelineState(pipelineState)
        computeEncoder.setTexture(inputTexture, index: 0)
        computeEncoder.setTexture(outputTexture, index: 1)
        computeEncoder.setBuffer(peakBuffer, offset: 0, index: 1)
        computeEncoder.setBuffer(countBuffer, offset: 0, index: 2)
        
        // Set shader parameters
        var metalParams = params
        computeEncoder.setBytes(
            &metalParams,
            length: MemoryLayout<PeakDetectionParams>.size,
            index: 0
        )
        
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
    
    private func filterPeaksByDistance(peaks: [DetectedPeak], minDistance: Float) -> [DetectedPeak] {
        guard peaks.count > 1 else { return peaks }
        
        // Sort by value (highest first)
        let sortedPeaks = peaks.sorted { $0.value > $1.value }
        var filteredPeaks: [DetectedPeak] = []
        
        for peak in sortedPeaks {
            var shouldKeep = true
            
            for existingPeak in filteredPeaks {
                let dx = peak.x - existingPeak.x
                let dy = peak.y - existingPeak.y
                let distance = sqrt(dx * dx + dy * dy)
                
                // If peaks are too close, discard the one with lower value
                if distance < minDistance {
                    shouldKeep = false
                    break
                }
            }
            
            if shouldKeep {
                filteredPeaks.append(peak)
            }
        }
        
        return filteredPeaks
    }
}

// MARK: - Helper Structures

/// Internal representation of detected peak data for Metal buffer
private struct DetectedPeakData {
    let x: Float
    let y: Float
    let value: Float
    let padding: Float // Padding to match memory layout in Metal
} 
