import Metal
import MetalKit

/// Base class for Metal shader operations
public class MetalEngine: @unchecked Sendable {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    var pipelineStates: [String: MTLComputePipelineState] = [:]
    private var metalLibrary: MTLLibrary?
    
    // Mapping from function names to their corresponding Metal files
    private let functionToFileMapping: [String: String] = [
        "debayerKernelRGGB": "Debayer",
        "squareCrop": "SquareCrop", 
        "donutMask": "DonutMask",
        "hsvPosition": "HSVPosition",
        "grayscale": "Grayscale",
        "invert": "Invert",
        "erosion": "Erosion",
        "blur": "Blur",
        "noise": "Noise",
        "peakDetection": "PeakDetection"
    ]
    
    private let shaderMap: [String: String] = [
        "grayscale": "Grayscale",
        "hsvPosition": "HSVPosition",
        "donutMask": "DonutMask",
        "squareCrop": "SquareCrop",
        "debayer": "Debayer"
    ]
    
    internal var textureMap: [String: MTLTexture] = [:]
    
    init?() {
        // Get the default Metal device
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("Failed to create Metal device")
            return nil
        }
        self.device = device
        
        // Create command queue
        guard let commandQueue = device.makeCommandQueue() else {
            print("Failed to create command queue")
            return nil
        }
        self.commandQueue = commandQueue
        
        // Initialize Metal library
        do {
            try initializeMetalLibrary()
        } catch {
            print("Failed to initialize Metal library: \(error)")
            return nil
        }
    }
    
    deinit {
        // Clear pipeline states
        pipelineStates.removeAll()
    }
    
    /// Initialize the Metal library by loading all shader sources
    private func initializeMetalLibrary() throws {
        // Try to load the pre-compiled library from the bundle first
        do {
            metalLibrary = try device.makeDefaultLibrary(bundle: Bundle.module)
            return
        } catch {
            // This is expected to fail in some environments, so we'll try other methods.
            print("Could not make default library from Bundle.module, falling back. Error: \(error)")
        }
        
        // If that fails, try to get the default system library
        if let defaultLibrary = device.makeDefaultLibrary() {
            metalLibrary = defaultLibrary
            return
        }
        
        // As a last resort, load and compile from source code
        print("Falling back to compiling Metal shaders from source.")
        var combinedSource = "#include <metal_stdlib>\nusing namespace metal;\n\n"
        
        for fileName in functionToFileMapping.values {
            guard let shaderURL = Bundle.module.url(forResource: "Shaders/\(fileName)", withExtension: "metal") else {
                throw MetalEngineError.generalError(message: "Failed to find Metal shader source file in bundle: Shaders/\(fileName).metal")
            }
            
            let shaderSource: String
            do {
                shaderSource = try String(contentsOf: shaderURL)
            } catch {
                throw MetalEngineError.generalError(message: "Failed to read Metal shader source \(fileName): \(error.localizedDescription)")
            }
            
            let cleanedSource = shaderSource
                .replacingOccurrences(of: "#include <metal_stdlib>", with: "")
                .replacingOccurrences(of: "using namespace metal;", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            combinedSource += "\n// From \(fileName).metal\n"
            combinedSource += cleanedSource + "\n\n"
        }
        
        do {
            metalLibrary = try device.makeLibrary(source: combinedSource, options: nil)
        } catch {
            throw MetalEngineError.generalError(message: "Failed to compile combined Metal library from source: \(error.localizedDescription)")
        }
    }
    
    /// Initialize a pipeline state for a shader
    func initializePipeline(name: String) throws -> MTLComputePipelineState {
        if let existing = pipelineStates[name] {
            return existing
        }
        
        guard let library = metalLibrary else {
            throw MetalEngineError.generalError(message: "Metal library not initialized")
        }
        
        guard let kernelFunction = library.makeFunction(name: name) else {
            throw MetalEngineError.shaderNotFound
        }
        
        do {
            let pipelineState = try device.makeComputePipelineState(function: kernelFunction)
            pipelineStates[name] = pipelineState
            return pipelineState
        } catch {
            throw MetalEngineError.pipelineCreationFailed(error)
        }
    }
    
    /// Create an input texture from RGBA data
    func createInputTexture(data: Data, width: Int, height: Int) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = .shaderRead
        descriptor.storageMode = .shared
        
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            return nil
        }
        
        let region = MTLRegionMake2D(0, 0, width, height)
        texture.replace(
            region: region,
            mipmapLevel: 0,
            withBytes: (data as NSData).bytes,
            bytesPerRow: width * 4 // RGBA = 4 bytes per pixel
        )
        
        return texture
    }
    
    /// Create an output texture
    func createOutputTexture(width: Int, height: Int) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Uint,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderWrite, .shaderRead]
        descriptor.storageMode = .shared
        
        return device.makeTexture(descriptor: descriptor)
    }
    
    /// Execute a shader with the given parameters
    func executeShader<P: MetalShaderParameters>(
        name: String,
        inputTexture: MTLTexture,
        outputTexture: MTLTexture,
        params: P,
        threadgroupSize: MTLSize? = nil
    ) throws {
        let pipelineState = try initializePipeline(name: name)
        
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw MetalEngineError.commandBufferCreationFailed
        }
        
        // Configure compute encoder
        computeEncoder.setComputePipelineState(pipelineState)
        computeEncoder.setTexture(inputTexture, index: 0)
        computeEncoder.setTexture(outputTexture, index: 1)
        
        // Set shader parameters safely using withUnsafeBytes
        let parameters = params
        withUnsafeBytes(of: parameters) { rawBufferPointer in
            computeEncoder.setBytes(
                rawBufferPointer.baseAddress!,
                length: MemoryLayout<P>.size,
                index: params.bufferIndex
            )
        }
        
        // Calculate threadgroup sizes
        let size = threadgroupSize ?? calculateOptimalThreadgroupSize(
            pipelineState: pipelineState,
            outputWidth: outputTexture.width,
            outputHeight: outputTexture.height
        )
        
        let threadgroupCount = MTLSize(
            width: (outputTexture.width + size.width - 1) / size.width,
            height: (outputTexture.height + size.height - 1) / size.height,
            depth: 1
        )
        
        // Dispatch work
        computeEncoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: size)
        computeEncoder.endEncoding()
        
        // Execute and wait for completion
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
    /// Calculate optimal threadgroup size for the given pipeline state
    func calculateOptimalThreadgroupSize(
        pipelineState: MTLComputePipelineState,
        outputWidth: Int,
        outputHeight: Int
    ) -> MTLSize {
        let w = pipelineState.threadExecutionWidth
        let h = pipelineState.maxTotalThreadsPerThreadgroup / w
        return MTLSize(width: w, height: h, depth: 1)
    }
} 
