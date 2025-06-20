//
//  MetalShaderResult+NSImage.swift
//  GravityWell
//
//  Created by Bryan Costanza on 6/7/25.
//

import Metal
import AppKit

extension MetalShaderResult {
    public var nsImage: NSImage? {
        guard let originalData = data,
              let flippedData = verticallyFlippedData(from: originalData, width: width, height: height, bytesPerPixel: 4),
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let provider = CGDataProvider(data: flippedData as CFData),
              let cgImage = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8, // Since we're using RGBA8
                bitsPerPixel: 32,   // 4 components * 8 bits
                bytesPerRow: width * 4, // 4 bytes per pixel (RGBA)
                space: colorSpace,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              ) else {
            return nil
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
    }
}

private func verticallyFlippedData(from data: Data, width: Int, height: Int, bytesPerPixel: Int) -> Data? {
    let bytesPerRow = width * bytesPerPixel
    guard data.count == bytesPerRow * height else { return nil }
    
    var flippedData = Data(count: data.count)
    
    for y in 0..<height {
        let originalRow = data.subdata(in: (y * bytesPerRow)..<((y + 1) * bytesPerRow))
        let flippedY = height - 1 - y
        flippedData.replaceSubrange((flippedY * bytesPerRow)..<((flippedY + 1) * bytesPerRow), with: originalRow)
    }
    
    return flippedData
}
