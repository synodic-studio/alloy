import Metal
import MetalKit

extension CommonMetalEngine {
    
    /// Apply circle detection to the current image and return both regular result and detected circles
    /// - Parameters:
    ///   - data: Input image data
    ///   - minDiameter: Minimum circle diameter to detect (default: 10)
    ///   - maxDiameter: Maximum circle diameter to detect (default: 100)
    ///   - threshold: Edge detection threshold (0.0-1.0, default: 0.3)
    ///   - maxCircles: Maximum number of circles to detect (default: 100)
    /// - Returns: CircleDetectionResult containing detected circles and processed texture
    public func executeWithCircleDetection(
        data: Data,
        minDiameter: Int = 10,
        maxDiameter: Int = 100,
        threshold: Float = 0.3,
        maxCircles: Int = 100
    ) throws -> CircleDetectionResult {
        // Validate parameters
        guard minDiameter > 0, maxDiameter > minDiameter else {
            throw MetalEngineError.generalError(message: "Invalid diameter range: minDiameter must be > 0 and maxDiameter must be > minDiameter")
        }
        
        guard threshold >= 0.0 && threshold <= 1.0 else {
            throw MetalEngineError.generalError(message: "Threshold must be between 0.0 and 1.0")
        }
        
        guard maxCircles > 0 else {
            throw MetalEngineError.generalError(message: "maxCircles must be greater than 0")
        }
        
        // Execute existing operations to get the current texture
        let intermediateResult = try execute(data: data)
        
        // Create output texture for edge detection visualization
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
        
        // Create buffer for detected circles
        let circleBufferLength = maxCircles * MemoryLayout<DetectedCircleData>.size
        guard let circleBuffer = device.makeBuffer(length: circleBufferLength, options: .storageModeShared) else {
            throw MetalEngineError.generalError(message: "Failed to create circle buffer")
        }
        
        // Create buffer for circle count
        guard let countBuffer = device.makeBuffer(length: MemoryLayout<UInt32>.size, options: .storageModeShared) else {
            throw MetalEngineError.generalError(message: "Failed to create count buffer")
        }
        
        // Initialize count to 0
        let countPointer = countBuffer.contents().bindMemory(to: UInt32.self, capacity: 1)
        countPointer[0] = 0
        
        // Execute circle detection shader
        try executeCircleDetectionShader(
            inputTexture: intermediateResult.texture,
            outputTexture: outputTexture,
            circleBuffer: circleBuffer,
            countBuffer: countBuffer,
                            params: SobelCircleDetectionParams(
                    minDiameter: minDiameter,
                    maxDiameter: maxDiameter,
                    threshold: threshold,
                    maxCircles: maxCircles
                )
        )
        
        // Read back the detected circles
        let detectedCount = Int(countPointer[0])
        var detectedCircles: [DetectedCircle] = []
        
        if detectedCount > 0 {
            let circleDataPointer = circleBuffer.contents().bindMemory(to: DetectedCircleData.self, capacity: maxCircles)
            
            for i in 0..<min(detectedCount, maxCircles) {
                let circleData = circleDataPointer[i]
                let circle = DetectedCircle(
                    x: circleData.x,
                    y: circleData.y,
                    diameter: circleData.radius * 2.0,
                    confidence: circleData.confidence
                )
                detectedCircles.append(circle)
            }
        }
        
        // Apply non-maximum suppression to remove overlapping detections
        detectedCircles = nonMaximumSuppression(circles: detectedCircles, overlapThreshold: 0.5)
        
        return CircleDetectionResult(
            texture: outputTexture,
            width: intermediateResult.width,
            height: intermediateResult.height,
            detectedCircles: detectedCircles
        )
    }
    
    // MARK: - Private Helper Methods
    
    private func executeCircleDetectionShader(
        inputTexture: MTLTexture,
        outputTexture: MTLTexture,
        circleBuffer: MTLBuffer,
        countBuffer: MTLBuffer,
        params: SobelCircleDetectionParams
    ) throws {
        let pipelineState = try initializePipeline(name: "circleDetection")
        
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw MetalEngineError.commandBufferCreationFailed
        }
        
        // Configure compute encoder
        computeEncoder.setComputePipelineState(pipelineState)
        computeEncoder.setTexture(inputTexture, index: 0)
        computeEncoder.setTexture(outputTexture, index: 1)
        computeEncoder.setBuffer(circleBuffer, offset: 0, index: 1)
        computeEncoder.setBuffer(countBuffer, offset: 0, index: 2)
        
        // Set shader parameters
        withUnsafeBytes(of: params) { rawBufferPointer in
            computeEncoder.setBytes(
                rawBufferPointer.baseAddress!,
                length: MemoryLayout<SobelCircleDetectionParams>.size,
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
    
    private func nonMaximumSuppression(circles: [DetectedCircle], overlapThreshold: Float) -> [DetectedCircle] {
        guard circles.count > 1 else { return circles }
        
        // Sort by confidence (highest first)
        let sortedCircles = circles.sorted { $0.confidence > $1.confidence }
        var filteredCircles: [DetectedCircle] = []
        
        for circle in sortedCircles {
            var shouldKeep = true
            
            for existingCircle in filteredCircles {
                let dx = circle.x - existingCircle.x
                let dy = circle.y - existingCircle.y
                let distance = sqrt(dx * dx + dy * dy)
                let minRadius = min(circle.radius, existingCircle.radius)
                
                // If circles overlap too much, discard the one with lower confidence
                if distance < minRadius * overlapThreshold {
                    shouldKeep = false
                    break
                }
            }
            
            if shouldKeep {
                filteredCircles.append(circle)
            }
        }
        
        return filteredCircles
    }
}

// MARK: - Helper Structures

/// Internal representation of detected circle data for Metal buffer
private struct DetectedCircleData {
    let x: Float
    let y: Float
    let radius: Float
    let confidence: Float
} 