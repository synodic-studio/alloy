import Metal
import MetalKit
import MetalPerformanceShaders

extension CommonMetalEngine {
    
    /// Apply peak finding circle detection using template matching
    /// - Parameters:
    ///   - data: Input image data
    ///   - minDiameter: Minimum circle diameter to detect (default: 10)
    ///   - maxDiameter: Maximum circle diameter to detect (default: 100)
    ///   - correlationThreshold: Correlation threshold (0.0-1.0, default: 0.7)
    ///   - maxPeaks: Maximum number of peaks to detect (default: 100)
    ///   - minDistance: Minimum distance between peaks (default: 10.0)
    /// - Returns: CircleDetectionResult containing detected circles and processed texture
    public func executeWithPeakCircleDetection(
        data: Data,
        minDiameter: Int = 10,
        maxDiameter: Int = 100,
        correlationThreshold: Float = 0.7,
        maxPeaks: Int = 100,
        minDistance: Float = 10.0
    ) async throws -> CircleDetectionResult {
        // Validate parameters
        guard minDiameter > 0, maxDiameter > minDiameter else {
            throw MetalEngineError.generalError(message: "Invalid diameter range: minDiameter must be > 0 and maxDiameter must be > minDiameter")
        }
        
        guard correlationThreshold >= 0.0 && correlationThreshold <= 1.0 else {
            throw MetalEngineError.generalError(message: "Correlation threshold must be between 0.0 and 1.0")
        }
        
        guard maxPeaks > 0 else {
            throw MetalEngineError.generalError(message: "maxPeaks must be greater than 0")
        }
        
        guard minDistance > 0 else {
            throw MetalEngineError.generalError(message: "minDistance must be greater than 0")
        }
        
        // Execute existing operations to get the current texture
        let intermediateResult = try execute(data: data)
        
        // Convert to single-channel float texture for template matching
        guard let inputTexture = try convertToFloatTexture(from: intermediateResult.texture) else {
            throw MetalEngineError.generalError(message: "Failed to convert texture to float format")
        }
        
        var allPeaks: [DetectedPeak] = []
        
        // Generate templates and run correlation for each radius
        let minRadius = minDiameter / 2
        let maxRadius = maxDiameter / 2
        
        for radius in minRadius...maxRadius {
            guard let templateTexture = try createCircleTemplate(radius: radius) else { continue }
            
            // Perform normalized cross-correlation
            guard let correlationTexture = try performTemplateMatching(
                input: inputTexture,
                template: templateTexture
            ) else { continue }
            
            // Find peaks in the correlation texture
            if let peaks = try await findPeaks(
                in: correlationTexture,
                radius: Float(radius),
                threshold: correlationThreshold,
                maxPeaks: maxPeaks,
                minDistance: minDistance
            ) {
                allPeaks.append(contentsOf: peaks)
            }
        }
        
        // Apply non-maximum suppression to remove overlapping detections
        let finalPeaks = nonMaximumSuppression(peaks: allPeaks, minDistance: minDistance)
        
        // Convert peaks to DetectedCircle objects
        let detectedCircles = finalPeaks.map { $0.detectedCircle }
        
        return CircleDetectionResult(
            texture: intermediateResult.texture, // Return original processed texture
            width: intermediateResult.width,
            height: intermediateResult.height,
            detectedCircles: detectedCircles
        )
    }
    
    // MARK: - Private Helper Methods
    
    private func convertToFloatTexture(from sourceTexture: MTLTexture) throws -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r32Float,
            width: sourceTexture.width,
            height: sourceTexture.height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        
        guard let floatTexture = device.makeTexture(descriptor: descriptor) else {
            throw MetalEngineError.textureCreationFailed
        }
        
        // Manually extract and convert the grayscale data
        let width = sourceTexture.width
        let height = sourceTexture.height
        let bytesPerRow = width * 4 // RGBA8Uint = 4 bytes per pixel
        var rawData = Data(count: height * bytesPerRow)
        
        sourceTexture.getBytes(
            rawData.withUnsafeMutableBytes { $0.baseAddress! },
            bytesPerRow: bytesPerRow,
            from: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0
        )
        
        // Convert RGBA8Uint to single channel float (grayscale)
        var floatData = [Float](repeating: 0, count: width * height)
        
        rawData.withUnsafeBytes { rawBytes in
            let pixels = rawBytes.bindMemory(to: UInt8.self)
            for i in 0..<(width * height) {
                let pixelOffset = i * 4
                let r = Float(pixels[pixelOffset]) / 255.0
                let g = Float(pixels[pixelOffset + 1]) / 255.0
                let b = Float(pixels[pixelOffset + 2]) / 255.0
                // Use luminance formula for grayscale conversion
                floatData[i] = 0.299 * r + 0.587 * g + 0.114 * b
            }
        }
        
        floatTexture.replace(
            region: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0,
            withBytes: floatData,
            bytesPerRow: width * MemoryLayout<Float>.size
        )
        
        return floatTexture
    }
    
    private func createCircleTemplate(radius: Int) throws -> MTLTexture? {
        let diameter = radius * 2 + 1
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r32Float,
            width: diameter,
            height: diameter,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead]
        
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw MetalEngineError.textureCreationFailed
        }
        
        let center = SIMD2<Float>(Float(radius), Float(radius))
        var data = [Float](repeating: 0, count: diameter * diameter)
        
        for y in 0..<diameter {
            for x in 0..<diameter {
                let pos = SIMD2<Float>(Float(x), Float(y))
                let dist = distance(pos, center)
                // Create anti-aliased circle template
                let value = 1.0 - smoothstep(Float(radius) - 0.5, Float(radius) + 0.5, dist)
                data[y * diameter + x] = value
            }
        }
        
        texture.replace(
            region: MTLRegionMake2D(0, 0, diameter, diameter),
            mipmapLevel: 0,
            withBytes: data,
            bytesPerRow: diameter * MemoryLayout<Float>.size
        )
        
        return texture
    }
    
    private func performTemplateMatching(input: MTLTexture, template: MTLTexture) throws -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r32Float,
            width: input.width,
            height: input.height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        
        guard let correlationTexture = device.makeTexture(descriptor: descriptor) else {
            throw MetalEngineError.textureCreationFailed
        }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw MetalEngineError.commandBufferCreationFailed
        }
        
        // Extract the kernel weights from the template texture
        let kernelWidth = template.width
        let kernelHeight = template.height
        var kernelWeights = [Float](repeating: 0, count: kernelWidth * kernelHeight)
        template.getBytes(
            &kernelWeights,
            bytesPerRow: kernelWidth * MemoryLayout<Float>.size,
            from: MTLRegionMake2D(0, 0, kernelWidth, kernelHeight),
            mipmapLevel: 0
        )
        
        // Normalize the kernel to have zero mean for better correlation
        let mean = kernelWeights.reduce(0, +) / Float(kernelWeights.count)
        let normalizedKernel = kernelWeights.map { $0 - mean }
        
        // Use MPSImageConvolution for template matching
        let convolution = MPSImageConvolution(
            device: device,
            kernelWidth: kernelWidth,
            kernelHeight: kernelHeight,
            weights: normalizedKernel
        )
        
        convolution.encode(
            commandBuffer: commandBuffer,
            sourceTexture: input,
            destinationTexture: correlationTexture
        )
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        return correlationTexture
    }
    
    private func findPeaks(
        in texture: MTLTexture,
        radius: Float,
        threshold: Float,
        maxPeaks: Int,
        minDistance: Float
    ) async throws -> [DetectedPeak]? {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw MetalEngineError.commandBufferCreationFailed
        }
        
        // Prepare pipeline state
        let pipelineState = try initializePipeline(name: "findPeaks")
        
        // Prepare buffers
        let peakBuffer = device.makeBuffer(
            length: MemoryLayout<DetectedPeak>.stride * maxPeaks,
            options: .storageModeShared
        )
        let peakCountBuffer = device.makeBuffer(
            length: MemoryLayout<UInt32>.size,
            options: .storageModeShared
        )
        
        guard let peakBuffer = peakBuffer, let peakCountBuffer = peakCountBuffer else {
            throw MetalEngineError.generalError(message: "Failed to create buffers")
        }
        
        // Initialize count to 0
        peakCountBuffer.contents().storeBytes(of: UInt32(0), as: UInt32.self)
        
        // Encode the compute command
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw MetalEngineError.commandBufferCreationFailed
        }
        
        computeEncoder.setComputePipelineState(pipelineState)
        computeEncoder.setTexture(texture, index: 0)
        computeEncoder.setBuffer(peakBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(peakCountBuffer, offset: 0, index: 1)
        
        var floatThreshold = threshold
        computeEncoder.setBytes(&floatThreshold, length: MemoryLayout<Float>.size, index: 2)
        var floatRadius = radius
        computeEncoder.setBytes(&floatRadius, length: MemoryLayout<Float>.size, index: 3)
        
        // Dispatch the kernel
        let threadgroupSize = calculateOptimalThreadgroupSize(
            pipelineState: pipelineState,
            outputWidth: texture.width,
            outputHeight: texture.height
        )
        
        let threadgroupCount = MTLSize(
            width: (texture.width + threadgroupSize.width - 1) / threadgroupSize.width,
            height: (texture.height + threadgroupSize.height - 1) / threadgroupSize.height,
            depth: 1
        )
        
        computeEncoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
        computeEncoder.endEncoding()
        
        // Commit and wait for completion
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        // Read back the results
        let count = Int(peakCountBuffer.contents().load(as: UInt32.self))
        guard count > 0 else { return [] }
        
        var peaks = [DetectedPeak]()
        let pointer = peakBuffer.contents().bindMemory(to: DetectedPeak.self, capacity: count)
        for i in 0..<min(count, maxPeaks) {
            peaks.append(pointer[i])
        }
        
        return peaks
    }
    
    private func nonMaximumSuppression(peaks: [DetectedPeak], minDistance: Float) -> [DetectedPeak] {
        var sortedPeaks = peaks.sorted { $0.correlation > $1.correlation }
        var finalPeaks: [DetectedPeak] = []
        
        while !sortedPeaks.isEmpty {
            let bestPeak = sortedPeaks.removeFirst()
            finalPeaks.append(bestPeak)
            
            sortedPeaks.removeAll { peak in
                distance(bestPeak.position, peak.position) < minDistance
            }
        }
        
        return finalPeaks
    }
}

// MARK: - Math Helpers

private func smoothstep(_ edge0: Float, _ edge1: Float, _ x: Float) -> Float {
    let t = max(0, min(1, (x - edge0) / (edge1 - edge0)))
    return t * t * (3.0 - 2.0 * t)
} 