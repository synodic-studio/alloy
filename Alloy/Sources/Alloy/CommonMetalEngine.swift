import Metal
import MetalKit

/// A unified Metal engine that uses a builder pattern to chain shader operations
public class CommonMetalEngine: MetalEngine, @unchecked Sendable {
    private var operations: [ShaderOperation] = []
    private var configuredWidth: Int = 0
    private var configuredHeight: Int = 0
    private var configuredBitDepth: Int = 8
    private var currentWidth: Int = 0
    private var currentHeight: Int = 0
    private var isRGBAInput: Bool = false
    
    /// Initialize with optional starting data
    public override init?() {
        super.init()
    }
    
    /// Configure the pipeline with dimensions and operations for raw sensor data
    public func withRawData(width: Int, height: Int, bitDepth: Int = 8) throws -> CommonMetalEngine {
        // Validate input parameters
        guard width > 0, height > 0 else {
            throw MetalEngineError.generalError(message: "Width and height must be greater than 0")
        }
        
        guard bitDepth == 8 || bitDepth == 16 else {
            throw MetalEngineError.generalError(message: "Bit depth must be 8 or 16")
        }
        
        self.configuredWidth = width
        self.configuredHeight = height
        self.configuredBitDepth = bitDepth
        self.currentWidth = width
        self.currentHeight = height
        self.isRGBAInput = false
        
        return self
    }
    
    /// Configure the pipeline with dimensions for already-processed RGBA data
    public func withRGBAData(width: Int, height: Int) throws -> CommonMetalEngine {
        // Validate input parameters
        guard width > 0, height > 0 else {
            throw MetalEngineError.generalError(message: "Width and height must be greater than 0")
        }
        
        self.configuredWidth = width
        self.configuredHeight = height
        self.configuredBitDepth = 8 // RGBA is always 8-bit per component
        self.currentWidth = width
        self.currentHeight = height
        self.isRGBAInput = true
        
        return self
    }
    
    /// Execute the configured pipeline with new input data
    public func execute(data: Data) throws -> BaseShaderResult {
        guard !operations.isEmpty else {
            throw MetalEngineError.generalError(message: "No operations to execute")
        }
        
        // Create input texture based on data type
        let inputTexture: MTLTexture
        if isRGBAInput {
            // Create RGBA texture for already-processed data
            let inputDescriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .rgba8Uint,
                width: configuredWidth,
                height: configuredHeight,
                mipmapped: false
            )
            inputDescriptor.usage = .shaderRead
            inputDescriptor.storageMode = .shared
            
            guard let texture = device.makeTexture(descriptor: inputDescriptor) else {
                throw MetalEngineError.textureCreationFailed
            }
            
            // Copy RGBA data to texture
            let region = MTLRegionMake2D(0, 0, configuredWidth, configuredHeight)
            texture.replace(
                region: region,
                mipmapLevel: 0,
                withBytes: (data as NSData).bytes,
                bytesPerRow: configuredWidth * 4 // 4 bytes per RGBA pixel
            )
            
            inputTexture = texture
        } else {
            // Create single-channel texture for raw sensor data
            let inputDescriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: configuredBitDepth == 16 ? .r16Uint : .r8Uint,
                width: configuredWidth,
                height: configuredHeight,
                mipmapped: false
            )
            inputDescriptor.usage = .shaderRead
            inputDescriptor.storageMode = .shared
            
            guard let texture = device.makeTexture(descriptor: inputDescriptor) else {
                throw MetalEngineError.textureCreationFailed
            }
            
            // Copy raw data to texture
            let region = MTLRegionMake2D(0, 0, configuredWidth, configuredHeight)
            texture.replace(
                region: region,
                mipmapLevel: 0,
                withBytes: (data as NSData).bytes,
                bytesPerRow: configuredWidth * (configuredBitDepth == 16 ? 2 : 1)
            )
            
            inputTexture = texture
        }
        
        // Execute the operations sequentially
        var currentTexture = inputTexture
        var currentWidth = configuredWidth
        var currentHeight = configuredHeight
        
        for i in 0..<operations.count {
            // Update the operation's input texture to the current texture
            operations[i].inputTexture = currentTexture
            
            // Execute the operation using the correct executeShader parameters
            if let typedOp = operations[i] as? TypedShaderOperation<DebayerParams> {
                try executeShader(
                    name: typedOp.name,
                    inputTexture: typedOp.inputTexture,
                    outputTexture: typedOp.outputTexture,
                    params: typedOp.params,
                    threadgroupSize: typedOp.threadgroupSize
                )
            } else if let typedOp = operations[i] as? TypedShaderOperation<MetalSquareCropParams> {
                try executeShader(
                    name: typedOp.name,
                    inputTexture: typedOp.inputTexture,
                    outputTexture: typedOp.outputTexture,
                    params: typedOp.params,
                    threadgroupSize: typedOp.threadgroupSize
                )
            } else if let typedOp = operations[i] as? TypedShaderOperation<DonutParams> {
                try executeShader(
                    name: typedOp.name,
                    inputTexture: typedOp.inputTexture,
                    outputTexture: typedOp.outputTexture,
                    params: typedOp.params,
                    threadgroupSize: typedOp.threadgroupSize
                )
            } else if let typedOp = operations[i] as? TypedShaderOperation<HSVPositionParams> {
                // Handle dimension inheritance for HSVPosition
                var finalParams = typedOp.params
                var finalOutputTexture = typedOp.outputTexture
                
                // Check if we need to inherit dimensions (0 means inherit)
                let needsWidthInheritance = typedOp.params.outputWidth == 0
                let needsHeightInheritance = typedOp.params.outputHeight == 0
                
                if needsWidthInheritance || needsHeightInheritance {
                    // Create new params with inherited dimensions
                    let inheritedWidth = needsWidthInheritance ? UInt32(currentWidth) : typedOp.params.outputWidth
                    let inheritedHeight = needsHeightInheritance ? UInt32(currentHeight) : typedOp.params.outputHeight
                    
                    finalParams = HSVPositionParams(
                        xComponent: typedOp.params.xComponent,
                        yComponent: typedOp.params.yComponent,
                        outputWidth: inheritedWidth,
                        outputHeight: inheritedHeight,
                        reverseX: typedOp.params.reverseX,
                        reverseY: typedOp.params.reverseY,
                        noiseAmount: typedOp.params.noiseAmount,
                        pixelSize: typedOp.params.pixelSize,
                        forceFullValue: typedOp.params.forceFullValue,
                        forceFullSaturation: typedOp.params.forceFullSaturation
                    )
                    
                    // Create new output texture with correct dimensions
                    let outputDescriptor = MTLTextureDescriptor.texture2DDescriptor(
                        pixelFormat: .rgba8Uint,
                        width: Int(inheritedWidth),
                        height: Int(inheritedHeight),
                        mipmapped: false
                    )
                    outputDescriptor.usage = [.shaderWrite, .shaderRead]
                    outputDescriptor.storageMode = .shared
                    
                    guard let newOutputTexture = device.makeTexture(descriptor: outputDescriptor) else {
                        throw MetalEngineError.textureCreationFailed
                    }
                    
                    finalOutputTexture = newOutputTexture
                }
                
                try executeShader(
                    name: typedOp.name,
                    inputTexture: typedOp.inputTexture,
                    outputTexture: finalOutputTexture,
                    params: finalParams,
                    threadgroupSize: typedOp.threadgroupSize
                )
                
                // Store the final output texture for use as currentTexture
                operations[i] = TypedShaderOperation(
                    name: typedOp.name,
                    inputTexture: typedOp.inputTexture,
                    outputTexture: finalOutputTexture,
                    params: finalParams,
                    threadgroupSize: typedOp.threadgroupSize
                )
            } else {
                throw MetalEngineError.generalError(message: "Unsupported operation type")
            }
            
            // Update current texture and dimensions for next operation
            currentTexture = operations[i].outputTexture
            if operations[i] is TypedShaderOperation<DebayerParams> {
                // Debayer halves dimensions
                currentWidth = currentWidth / 2
                currentHeight = currentHeight / 2
            } else if let typedOp = operations[i] as? TypedShaderOperation<MetalSquareCropParams> {
                // Crop changes dimensions to the crop size
                currentWidth = Int(typedOp.params.sideLength)
                currentHeight = Int(typedOp.params.sideLength)
            } else if let typedOp = operations[i] as? TypedShaderOperation<HSVPositionParams> {
                // HSV positioning changes dimensions - handle inheritance
                let finalWidth = typedOp.params.outputWidth == 0 ? UInt32(currentWidth) : typedOp.params.outputWidth
                let finalHeight = typedOp.params.outputHeight == 0 ? UInt32(currentHeight) : typedOp.params.outputHeight
                currentWidth = Int(finalWidth)
                currentHeight = Int(finalHeight)
            }
            // Mask operations don't change dimensions
        }
        
        return BaseShaderResult(
            texture: currentTexture,
            width: currentWidth,
            height: currentHeight
        )
    }
    
    /// Execute and convert to NSImage
    public func executeToImage(data: Data) throws -> NSImage? {
        let result = try execute(data: data)
        return result.nsImage
    }
    
    /// Reset the engine for a new operation chain
    func reset() -> CommonMetalEngine {
        operations.removeAll()
        configuredWidth = 0
        configuredHeight = 0
        configuredBitDepth = 8
        currentWidth = 0
        currentHeight = 0
        isRGBAInput = false
        return self
    }
    
    // MARK: - Internal Helper Methods
    
    internal func addOperation(_ operation: ShaderOperation) {
        operations.append(operation)
        
        // Update dimensions based on operation type
        if operation is TypedShaderOperation<DebayerParams> {
            // Debayer halves dimensions
            currentWidth = currentWidth / 2
            currentHeight = currentHeight / 2
        } else if let typedOp = operation as? TypedShaderOperation<MetalSquareCropParams> {
            // Crop changes dimensions to the crop size
            currentWidth = Int(typedOp.params.sideLength)
            currentHeight = Int(typedOp.params.sideLength)
        } else if let typedOp = operation as? TypedShaderOperation<HSVPositionParams> {
            // HSV positioning changes dimensions - handle inheritance
            let finalWidth = typedOp.params.outputWidth == 0 ? UInt32(currentWidth) : typedOp.params.outputWidth
            let finalHeight = typedOp.params.outputHeight == 0 ? UInt32(currentHeight) : typedOp.params.outputHeight
            currentWidth = Int(finalWidth)
            currentHeight = Int(finalHeight)
        }
        // Mask operations don't change dimensions
    }
    
    internal var inputWidth: Int {
        return currentWidth
    }
    
    internal var inputHeight: Int {
        return currentHeight
    }
    
    internal var inputBitDepth: Int {
        return configuredBitDepth
    }
}
