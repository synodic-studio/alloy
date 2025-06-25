import Metal
import AppKit

extension MTLTexture {
    /// Convert MTLTexture to NSImage
    func toNSImage(width: Int, height: Int) -> NSImage? {
        guard self.pixelFormat == .rgba8Unorm || self.pixelFormat == .rgba8Uint else {
            print("Unsupported texture format for NSImage conversion")
            return nil
        }

        let bytesPerRow = width * 4
        let dataLength = bytesPerRow * height
        let buffer = UnsafeMutableRawPointer.allocate(byteCount: dataLength, alignment: 1)
        defer { buffer.deallocate() }

        self.getBytes(
            buffer,
            bytesPerRow: bytesPerRow,
            from: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0
        )

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: buffer,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }

        guard let cgImage = context.makeImage() else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
    }
    
    /// Convert MTLTexture to RGBA Data
    func toRGBAData() -> Data? {
        guard self.pixelFormat == .rgba8Unorm || self.pixelFormat == .rgba8Uint else {
            print("Unsupported texture format for RGBA data conversion")
            return nil
        }

        let width = self.width
        let height = self.height
        let bytesPerRow = width * 4
        let dataLength = bytesPerRow * height
        
        var data = Data(count: dataLength)
        
        data.withUnsafeMutableBytes { ptr in
            self.getBytes(
                ptr.baseAddress!,
                bytesPerRow: bytesPerRow,
                from: MTLRegionMake2D(0, 0, width, height),
                mipmapLevel: 0
            )
        }
        
        return data
    }
} 