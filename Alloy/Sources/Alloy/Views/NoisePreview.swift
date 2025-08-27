import AppKit
import SwiftUI

struct NoisePreview: View {
    @State private var magnitude: Double = 0.2
    @State private var seed: UInt32 = 42
    @State private var ignoreBlack: Bool = false
    @State private var ignoreWhite: Bool = false

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
        VStack(spacing: 12) {
            Slider(value: $magnitude, in: 0.0 ... 0.5) {
                Text("Magnitude: \(magnitude, specifier: "%.2f")")
            }

            HStack {
                Text("Seed: \(seed)")
                Spacer()
                Button("Random") {
                    seed = UInt32.random(in: 0 ... UInt32.max)
                }
            }

            VStack(spacing: 8) {
                Toggle("Ignore Black Pixels", isOn: $ignoreBlack)
                Toggle("Ignore White Pixels", isOn: $ignoreWhite)
            }
            .toggleStyle(.checkbox)
        }
        .padding()
        .frame(maxWidth: 300)
        .monospacedDigit()
    }

    private var originalImage: NSImage {
        createTestImage()
    }

    private var noisyImage: NSImage? {
        processImage(useGrayscale: false)
    }

    private var grayscaleNoisyImage: NSImage? {
        processImage(useGrayscale: true)
    }

    private func createTestImage() -> NSImage {
        let image = NSImage(size: NSSize(width: imageSize, height: imageSize))
        image.lockFocus()

        // Create a simple gradient pattern
        for y in 0 ..< Int(imageSize) {
            for x in 0 ..< Int(imageSize) {
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

        // Add pure black and white regions to test the ignore options
        NSColor.black.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 2, height: 2)).fill()

        NSColor.white.setFill()
        NSBezierPath(rect: NSRect(x: 30, y: 30, width: 2, height: 2)).fill()

        image.unlockFocus()
        return image
    }

    private func createGrayscaleTestImage() -> NSImage {
        let image = NSImage(size: NSSize(width: imageSize, height: imageSize))
        image.lockFocus()

        // Create a checkerboard pattern in grayscale
        for y in 0 ..< Int(imageSize) {
            for x in 0 ..< Int(imageSize) {
                let isLight = (x + y) % 2 == 0
                let grayValue = isLight ? 0.8 : 0.2
                let color = NSColor(white: grayValue, alpha: 1.0)
                color.setFill()

                let rect = NSRect(x: x, y: y, width: 1, height: 1)
                NSBezierPath(rect: rect).fill()
            }
        }

        // Add some grayscale regions
        NSColor(white: 0.8, alpha: 1.0).setFill()
        NSBezierPath(rect: NSRect(x: 8, y: 8, width: 5, height: 5)).fill()

        NSColor(white: 0.2, alpha: 1.0).setFill()
        NSBezierPath(rect: NSRect(x: 18, y: 18, width: 5, height: 6)).fill()

        // Add pure black and white regions to test the ignore options
        NSColor.black.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 5, height: 5)).fill()

        NSColor.white.setFill()
        NSBezierPath(rect: NSRect(x: 27, y: 27, width: 5, height: 5)).fill()

        image.unlockFocus()
        return image
    }

    private var grayscaleTestImage: NSImage {
        createGrayscaleTestImage()
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
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue,
            )
        }

        guard let context else { return nil }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        do {
            guard let engine = CommonMetalEngine() else { return nil }
            return try engine
                .withRGBAData(width: width, height: height)
                .noise(magnitude: magnitude, seed: seed, ignoreBlack: ignoreBlack, ignoreWhite: ignoreWhite)
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
