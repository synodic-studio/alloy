import Metal
import MetalKit

/// HSV component enumeration for pixel positioning
public enum HSVAxis: UInt32 {
    case hue = 0
    case saturation = 1
    case value = 2
}

public extension CommonMetalEngine {
    /// Position pixels based on HSV components
    /// - Parameters:
    ///   - xAxis: HSV component to use for X positioning (hue, saturation, or value)
    ///   - yAxis: HSV component to use for Y positioning (hue, saturation, or value)
    ///   - width: Output image width (default: nil, inherits from input image)
    ///   - height: Output image height (default: nil, inherits from input image)
    ///   - reverseX: Whether to reverse the X axis direction (default: false)
    ///   - reverseY: Whether to reverse the Y axis direction (default: false)
    ///   - noiseAmount: Amount of random noise to add in pixels to spread out overlapping pixels (default: 3.0)
    ///   - pixelSize: Size of each plotted pixel (width and height in pixels, default: 1)
    ///   - forceFullValue: Force value component to full (1.0) regardless of input (default: false)
    ///   - forceFullSaturation: Force saturation component to full (1.0) regardless of input (default: false)
    /// - Returns: CommonMetalEngine for chaining
    func hsvPosition(
        xAxis: HSVAxis,
        yAxis: HSVAxis,
        width: Int? = nil,
        height: Int? = nil,
        reverseX: Bool = false,
        reverseY: Bool = false,
        noiseAmount: Float = 10.0,
        pixelSize: Int = 1,
        forceFullValue: Bool = false,
        forceFullSaturation: Bool = false
    ) throws -> CommonMetalEngine {
        // Validate parameters (only if specified)
        if let width, width <= 0 {
            throw MetalEngineError.generalError(message: "Width must be greater than 0 when specified")
        }
        if let height, height <= 0 {
            throw MetalEngineError.generalError(message: "Height must be greater than 0 when specified")
        }

        guard xAxis != yAxis else {
            throw MetalEngineError.generalError(message: "X and Y axes must use different HSV components")
        }

        guard pixelSize > 0 else {
            throw MetalEngineError.generalError(message: "Pixel size must be greater than 0")
        }

        // Use defaults for texture creation, will be resized during execution if needed
        let defaultWidth = width ?? 1
        let defaultHeight = height ?? 1

        // Create output texture
        let outputDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Uint,
            width: defaultWidth,
            height: defaultHeight,
            mipmapped: false,
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
            mipmapped: false,
        )
        guard let tempTexture = device.makeTexture(descriptor: tempDescriptor) else {
            throw MetalEngineError.textureCreationFailed
        }

        // Create operation - use 0 as sentinel value for inherited dimensions
        let operation = TypedShaderOperation(
            name: "hsvPosition",
            inputTexture: tempTexture,
            outputTexture: outputTexture,
            params: HSVPositionParams(
                xComponent: xAxis.rawValue,
                yComponent: yAxis.rawValue,
                outputWidth: UInt32(width ?? 0), // 0 means inherit from input
                outputHeight: UInt32(height ?? 0), // 0 means inherit from input
                reverseX: reverseX ? 1 : 0,
                reverseY: reverseY ? 1 : 0,
                noiseAmount: noiseAmount,
                pixelSize: UInt32(pixelSize),
                forceFullValue: forceFullValue ? 1 : 0,
                forceFullSaturation: forceFullSaturation ? 1 : 0,
            ),
            threadgroupSize: nil,
        )

        addOperation(operation)

        return self
    }

    // MARK: - HSV Position Presets

    /// Preset: Saturation vs Value positioning (reversed Y-axis for intuitive brightness direction)
    /// Maps pixel saturation to X-axis and brightness/value to Y-axis with Y reversed
    /// - Parameters:
    ///   - pixelSize: Size of each plotted pixel (width and height in pixels, default: 1)
    /// - Returns: CommonMetalEngine for chaining
    func hsvPositionSaturationValue(
        pixelSize: Int = 1
    ) throws -> CommonMetalEngine {
        try hsvPosition(
            xAxis: .saturation,
            yAxis: .value,
            reverseY: true,
            pixelSize: pixelSize,
        )
    }

    /// Preset: Hue vs Value positioning (reversed Y-axis for intuitive brightness direction)
    /// Maps pixel hue to X-axis and brightness/value to Y-axis with Y reversed
    /// - Parameters:
    ///   - pixelSize: Size of each plotted pixel (width and height in pixels, default: 1)
    ///   - forceFullSaturation: Force saturation component to full (1.0) regardless of input (default: false)
    /// - Returns: CommonMetalEngine for chaining
    func hsvPositionHueValue(
        pixelSize: Int = 1,
        forceFullSaturation: Bool = false
    ) throws -> CommonMetalEngine {
        try hsvPosition(
            xAxis: .hue,
            yAxis: .value,
            reverseY: true,
            pixelSize: pixelSize,
            forceFullSaturation: forceFullSaturation,
        )
    }

    /// Preset: Hue vs Saturation positioning (reversed Y-axis for intuitive saturation direction)
    /// Maps pixel hue to X-axis and saturation to Y-axis with Y reversed
    /// - Parameters:
    ///   - pixelSize: Size of each plotted pixel (width and height in pixels, default: 1)
    ///   - forceFullValue: Force value component to full (1.0) regardless of input (default: false)
    /// - Returns: CommonMetalEngine for chaining
    func hsvPositionHueSaturation(
        pixelSize: Int = 1,
        forceFullValue: Bool = false
    ) throws -> CommonMetalEngine {
        try hsvPosition(
            xAxis: .hue,
            yAxis: .saturation,
            reverseY: true,
            pixelSize: pixelSize,
            forceFullValue: forceFullValue,
        )
    }
}
