import SwiftUI
import AppKit

struct BlurPreview: View {
    @State private var radius: Double = 1.0
    
    private let imageSize: CGFloat = 32
    private let displaySize: CGFloat = 256

    var body: some View {
        VStack {
            imageComparison
            controls
        }
        .padding()
    }
    
    private var imageComparison: some View {
        VStack(spacing: 20) {
            originalImageView
            blurredImageView
        }
    }
    
    private var originalImageView: some View {
        VStack {
            Text("Original")
                .font(.headline)
            Image(nsImage: originalImage)
                .resizable()
                .interpolation(.none)
                .frame(width: displaySize, height: displaySize)
                .border(Color.gray)
        }
    }
    
    private var blurredImageView: some View {
        VStack {
            Text("Blurred")
                .font(.headline)
            if let blurredImage {
                Image(nsImage: blurredImage)
                    .resizable()
                    .interpolation(.none)
                    .frame(width: displaySize, height: displaySize)
                    .border(Color.gray)
            } else {
                Rectangle()
                    .fill(Color.gray)
                    .frame(width: displaySize, height: displaySize)
                    .overlay(Text("Error"))
            }
        }
    }
    
    private var controls: some View {
        VStack {
            Slider(value: $radius, in: 0.5...5.0) {
                Text("Radius: \(radius, specifier: "%.1f")")
            }
        }
        .padding()
        .frame(maxWidth: 300)
        .monospacedDigit()
    }

    private var originalImage: NSImage {
        return createTestImage()
    }

    private var blurredImage: NSImage? {
        return processImage()
    }
    
    private func createTestImage() -> NSImage {
        let image = NSImage(size: NSSize(width: imageSize, height: imageSize))
        image.lockFocus()

        // Create a simple checkerboard pattern
        for y in 0..<Int(imageSize) {
            for x in 0..<Int(imageSize) {
                let isWhite = (x + y) % 2 == 0
                let color = isWhite ? NSColor.white : NSColor.black
                color.setFill()
                
                let rect = NSRect(x: x, y: y, width: 1, height: 1)
                NSBezierPath(rect: rect).fill()
            }
        }
        
        // Add a few colored pixels for interest
        NSColor.red.setFill()
        NSBezierPath(rect: NSRect(x: 8, y: 8, width: 1, height: 1)).fill()
        
        NSColor.blue.setFill()
        NSBezierPath(rect: NSRect(x: 24, y: 24, width: 1, height: 1)).fill()
        
        NSColor.green.setFill()
        NSBezierPath(rect: NSRect(x: 16, y: 8, width: 1, height: 1)).fill()

        image.unlockFocus()
        return image
    }
    
    private func processImage() -> NSImage? {
        guard let cgImage = originalImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { 
            print("BlurPreview: Failed to get CGImage from original image")
            return nil 
        }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = width * 4
        var data = Data(count: height * bytesPerRow)
        
        let context = data.withUnsafeMutableBytes { ptr -> CGContext? in
            CGContext(
                data: ptr.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
            )
        }

        guard let context else { 
            print("BlurPreview: Failed to create CGContext")
            return nil 
        }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        do {
            guard let engine = CommonMetalEngine() else { 
                print("BlurPreview: Failed to create CommonMetalEngine")
                return nil 
            }
            print("BlurPreview: Processing blur with radius \(radius) on \(width)x\(height) image")
            return try engine
                .withRGBAData(width: width, height: height)
                .blur(radius: radius)
                .executeToImage(data: data)
        } catch {
            print("BlurPreview: Error processing image: \(error)")
            return nil
        }
    }
}

#Preview {
    BlurPreview()
} 
