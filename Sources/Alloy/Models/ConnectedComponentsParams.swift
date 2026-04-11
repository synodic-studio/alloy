import Metal

/// Parameters for connected components analysis
struct ConnectedComponentsParams: MetalShaderParameters {
    let maxComponents: UInt32 // Maximum number of components to detect - 4 bytes
    let maxPixelsPerBlob: UInt32 // Maximum pixels allowed per blob (area filter) - 4 bytes
    let searchWindowSize: UInt32 // Search window size for flood fill - 4 bytes
    private let _padding: UInt32 = 0 // Padding to align to 16 bytes - 4 bytes

    var bufferIndex: Int { 0 }

    init(maxComponents: Int = 50, maxPixelsPerBlob: Int = 100, searchWindowSize: Int = 20) {
        self.maxComponents = UInt32(maxComponents)
        self.maxPixelsPerBlob = UInt32(maxPixelsPerBlob)
        self.searchWindowSize = UInt32(searchWindowSize)
    }
}

/// Result of connected components analysis containing centroid information
public struct ComponentCentroid {
    /// X coordinate of the centroid
    public let x: Float

    /// Y coordinate of the centroid
    public let y: Float

    /// Number of pixels in this component
    public let pixelCount: UInt32

    public init(x: Float, y: Float, pixelCount: UInt32) {
        self.x = x
        self.y = y
        self.pixelCount = pixelCount
    }
}

/// Result containing both texture output and detected centroids
public struct ConnectedComponentsResult: MetalShaderResult {
    public let texture: MTLTexture
    public let width: Int
    public let height: Int
    public let centroids: [ComponentCentroid]

    public init(texture: MTLTexture, width: Int, height: Int, centroids: [ComponentCentroid]) {
        self.texture = texture
        self.width = width
        self.height = height
        self.centroids = centroids
    }
}

// MARK: - Internal Metal Buffer Structures

/// Internal structure for component data in Metal buffers
struct ComponentData {
    let centroidX: Float
    let centroidY: Float
    let pixelCount: UInt32
    let padding: UInt32 // For memory alignment
}
