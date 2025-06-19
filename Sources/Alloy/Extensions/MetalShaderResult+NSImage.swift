//
//  MetalShaderResult+NSImage.swift
//  GravityWell
//
//  Created by Bryan Costanza on 6/7/25.
//

import Metal
import AppKit

extension MetalShaderResult {
    var nsImage: NSImage? {
        guard let rgbData = data,
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let provider = CGDataProvider(data: rgbData as CFData),
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
