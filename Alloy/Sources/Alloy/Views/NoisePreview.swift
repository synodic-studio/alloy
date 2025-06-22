import SwiftUI
import AppKit

struct NoisePreview: View {
    @State private var magnitude: Double = 0.2
    @State private var seed: UInt32 = 42
    
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
        VStack(spacing: 15) {
            originalImageView
            noisyImageView
            grayscaleNoisyImageView
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
    
    private var noisyImageView: some View {
        VStack {
            Text("Color + Noise")
                .font(.headline)
            if let noisyImage {
                Image(nsImage: noisyImage)
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
    
    private var grayscaleNoisyImageView: some View {
        VStack {
            Text("Grayscale + Noise")
                .font(.headline)
            if let grayscaleNoisyImage {
                Image(nsImage: grayscaleNoisyImage)
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
            Slider(value: $magnitude, in: 0.0...0.5) {
                Text("Magnitude: \(magnitude, specifier: "%.2f")")
            }
            
            HStack {
                Text("Seed: \(seed)")
                Spacer()
                Button("Random") {
                    seed = UInt32.random(in: 0...UInt32.max)
                }
            }
        }
        .padding()
        .frame(maxWidth: 300)
        .monospacedDigit()
    }

    private var originalImage: NSImage {
        return createTestImage()
    }

    private var noisyImage: NSImage? {
        return processImage(useGrayscale: false)
    }
    
    private var grayscaleNoisyImage: NSImage? {
        return processImage(useGrayscale: true)
    }
    
    private func createTestImage() -> NSImage {
        let image = NSImage(size: NSSize(width: imageSize, height: imageSize))
        image.lockFocus()

        // Create a simple gradient pattern
        for y in 0..<Int(imageSize) {
            for x in 0..<Int(imageSize) {
                let intensity = Double(x + y) / Double(imageSize * 2)
                let color = NSColor(white: intensity, alpha: 1.0)
                color.setFill()
                
                let rect = NSRect(x: x, y: y, width: 1, height: 1)
                NSBezierPath(rect: rect).fill()
            }
        }
        
        // Add some solid colored regions
        NSColor.red.setFill()
        NSBezierPath(rect: NSRect(x: 4, y: 4, width: 4, height: 4)).fill()
        
        NSColor.blue.setFill()
        NSBezierPath(rect: NSRect(x: 24, y: 24, width: 4, height: 4)).fill()

        image.unlockFocus()
        return image
    }
    
    private func createGrayscaleTestImage() -> NSImage {
        let image = NSImage(size: NSSize(width: imageSize, height: imageSize))
        image.lockFocus()

        // Create a checkerboard pattern in grayscale
        for y in 0..<Int(imageSize) {
            for x in 0..<Int(imageSize) {
                let isLight = (x + y) % 2 == 0
                let grayValue = isLight ? 0.8 : 0.2
                let color = NSColor(white: grayValue, alpha: 1.0)
                color.setFill()
                
                let rect = NSRect(x: x, y: y, width: 1, height: 1)
                NSBezierPath(rect: rect).fill()
            }
        }
        
        // Add some grayscale regions
        NSColor(white: 0.9, alpha: 1.0).setFill()
        NSBezierPath(rect: NSRect(x: 6, y: 6, width: 6, height: 6)).fill()
        
        NSColor(white: 0.1, alpha: 1.0).setFill()
        NSBezierPath(rect: NSRect(x: 20, y: 20, width: 6, height: 6)).fill()

        image.unlockFocus()
        return image
    }
    
    private var grayscaleTestImage: NSImage {
        return createGrayscaleTestImage()
    }
    
    private func processImage(useGrayscale: Bool) -> NSImage? {
        let sourceImage = useGrayscale ? grayscaleTestImage : originalImage
        guard let cgImage = sourceImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }

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

        guard let context else { return nil }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        do {
            guard let engine = CommonMetalEngine() else { return nil }
            return try engine
                .withRGBAData(width: width, height: height)
                .noise(magnitude: magnitude, seed: seed)
                .executeToImage(data: data)
        } catch {
            print("Error processing image: \(error)")
            return nil
        }
    }
}

#Preview {
    NoisePreview()
} 
