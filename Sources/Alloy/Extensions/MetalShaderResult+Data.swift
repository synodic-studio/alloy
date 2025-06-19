import Metal
import CoreGraphics

extension MetalShaderResult {
    var data: Data? {
        let bytesPerRow = width * 4 // RGBA = 4 bytes per pixel
        let size = bytesPerRow * height
        var data = Data(count: size)
        
        data.withUnsafeMutableBytes { ptr in
            texture.getBytes(
                ptr.baseAddress!,
                bytesPerRow: bytesPerRow,
                from: MTLRegionMake2D(0, 0, width, height),
                mipmapLevel: 0
            )
        }
        return data
    }
} 
