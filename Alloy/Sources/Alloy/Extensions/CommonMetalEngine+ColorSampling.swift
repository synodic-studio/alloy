import Metal
import MetalKit

/// Result structure for color sampling operation
public struct ColorSamplingResult {
    public let colors: [NSColor]     // Array of sampled colors
    public let positions: [CGPoint]  // Original positions sampled

    public init(colors: [NSColor], positions: [CGPoint]) {
        self.colors = colors
        self.positions = positions
    }
}

public extension CommonMetalEngine {
    /// Execute GPU-based color sampling at specified positions
    /// - Parameters:
    ///   - inputTexture: GPU texture containing color image
    ///   - positions: Array of CGPoint positions to sample
    ///   - radius: Sampling radius (default: 3.0)
    /// - Returns: ColorSamplingResult with extracted colors
    func executeSampling(
        inputTexture: MTLTexture,
        positions: [CGPoint],
        radius: Float = 3.0
    ) throws -> ColorSamplingResult {
        guard !positions.isEmpty else {
            return ColorSamplingResult(colors: [], positions: [])
        }

        // Convert positions to Metal-compatible format
        var samplePositions = positions.map {
            SamplePosition(x: Float($0.x), y: Float($0.y))
        }

        // Create position buffer
        let positionBufferLength = positions.count * MemoryLayout<SamplePosition>.size
        guard let positionBuffer = device.makeBuffer(
            bytes: &samplePositions,
            length: positionBufferLength,
            options: .storageModeShared
        ) else {
            throw MetalEngineError.generalError(message: "Failed to create position buffer")
        }

        // Create output color buffer
        let colorBufferLength = positions.count * MemoryLayout<ColorResult>.size
        guard let colorBuffer = device.makeBuffer(
            length: colorBufferLength,
            options: .storageModeShared
        ) else {
            throw MetalEngineError.generalError(message: "Failed to create color buffer")
        }

        // Execute shader
        try executeColorSamplingShader(
            inputTexture: inputTexture,
            positionBuffer: positionBuffer,
            colorBuffer: colorBuffer,
            sampleCount: positions.count,
            radius: radius
        )

        // Read results from GPU buffer
        let colorPointer = colorBuffer.contents().bindMemory(
            to: ColorResult.self,
            capacity: positions.count
        )

        let colors = (0 ..< positions.count).map { i in
            let result = colorPointer[i]
            return NSColor(
                red: CGFloat(result.r),
                green: CGFloat(result.g),
                blue: CGFloat(result.b),
                alpha: CGFloat(result.a)
            )
        }

        return ColorSamplingResult(colors: colors, positions: positions)
    }

    // MARK: - Private Implementation

    private func executeColorSamplingShader(
        inputTexture: MTLTexture,
        positionBuffer: MTLBuffer,
        colorBuffer: MTLBuffer,
        sampleCount: Int,
        radius: Float
    ) throws {
        // Initialize pipeline state
        let pipelineState = try initializePipeline(name: "sampleColors")

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder()
        else {
            throw MetalEngineError.commandBufferCreationFailed
        }

        // Configure compute encoder
        computeEncoder.setComputePipelineState(pipelineState)
        computeEncoder.setTexture(inputTexture, index: 0)
        computeEncoder.setBuffer(positionBuffer, offset: 0, index: 1)
        computeEncoder.setBuffer(colorBuffer, offset: 0, index: 2)

        // Set shader parameters
        let params = ColorSamplingParams(
            sampleCount: UInt32(sampleCount),
            radius: radius
        )
        withUnsafeBytes(of: params) { rawBufferPointer in
            computeEncoder.setBytes(
                rawBufferPointer.baseAddress!,
                length: MemoryLayout<ColorSamplingParams>.size,
                index: 0
            )
        }

        // Calculate threadgroup sizes
        // For small sample counts, use 1D dispatch
        let threadgroupSize = MTLSize(
            width: min(sampleCount, pipelineState.threadExecutionWidth),
            height: 1,
            depth: 1
        )

        let threadgroupCount = MTLSize(
            width: (sampleCount + threadgroupSize.width - 1) / threadgroupSize.width,
            height: 1,
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

// MARK: - Metal Structs

/// Metal struct matching shader SamplePosition
struct SamplePosition {
    var x: Float
    var y: Float
}

/// Metal struct matching shader ColorResult
struct ColorResult {
    var r: Float
    var g: Float
    var b: Float
    var a: Float
}

/// Metal struct matching shader ColorSamplingParams
struct ColorSamplingParams {
    var sampleCount: UInt32
    var radius: Float
    var padding1: UInt32 = 0
    var padding2: UInt32 = 0
}
