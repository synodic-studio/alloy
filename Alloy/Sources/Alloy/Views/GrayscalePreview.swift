import SwiftUI
import AppKit

struct GrayscalePreview: View {
    @State private var strategy: GrayscaleConversionStrategy = .weighted
    @State private var blackThreshold: Double = 0.0
    @State private var whiteThreshold: Double = 1.0

    private let imageSize: CGFloat = 256

    var body: some View {
        VStack {
            VStack {
                Text("Original")
                    .font(.headline)
                Image(nsImage: originalImage)
                    .resizable()
                    .frame(width: imageSize, height: imageSize)
                    .border(Color.gray)
            }
            .padding(.bottom)

            VStack {
                Text("Grayscale")
                    .font(.headline)
                if let grayscaleImage {
                    Image(nsImage: grayscaleImage)
                        .resizable()
                        .frame(width: imageSize, height: imageSize)
                        .border(Color.gray)
                } else {
                    Rectangle()
                        .fill(Color.gray)
                        .frame(width: imageSize, height: imageSize)
                        .overlay(Text("Error"))
                }
            }

            Form {
                Picker("Strategy:", selection: $strategy) {
                    ForEach(GrayscaleConversionStrategy.allCases, id: \.self) { strategy in
                        Text(strategy.displayName).tag(strategy)
                    }
                }

                Slider(value: $blackThreshold, in: 0.0...1.0) {
                    Text("Black Threshold: \(blackThreshold, specifier: "%.2f")")
                }

                Slider(value: $whiteThreshold, in: 0.0...1.0) {
                    Text("White Threshold: \(whiteThreshold, specifier: "%.2f")")
                }
            }
            .padding()
            .frame(maxWidth: 300)
            .monospacedDigit()
        }
        .padding()
        .onChange(of: blackThreshold) {
            if blackThreshold >= whiteThreshold {
                whiteThreshold = min(1.0, blackThreshold + 0.01)
            }
        }
        .onChange(of: whiteThreshold) {
            if whiteThreshold <= blackThreshold {
                blackThreshold = max(0.0, whiteThreshold - 0.01)
            }
        }
    }

    private var originalImage: NSImage {
        return Self.generateTestImage(size: NSSize(width: imageSize, height: imageSize))
    }

    private var grayscaleImage: NSImage? {
        guard let cgImage = originalImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = width * 4
        var data = Data(count: height * bytesPerRow)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

        let context = data.withUnsafeMutableBytes { (ptr: UnsafeMutableRawBufferPointer) -> CGContext? in
            return CGContext(
                data: ptr.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            )
        }

        guard let context else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        do {
            guard let engine = CommonMetalEngine() else { return nil }
            return try engine
                .withRGBAData(width: width, height: height)
                .grayscale(
                    strategy: strategy,
                    blackThreshold: blackThreshold,
                    whiteThreshold: whiteThreshold
                )
                .executeToImage(data: data)
        } catch {
            print("Error processing image: \(error)")
            return nil
        }
    }

    static func generateTestImage(size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()

        NSColor(white: 0.2, alpha: 1.0).setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

        let colors: [NSColor] = [.red, .green, .blue, .yellow, .cyan, .magenta]
        let circleRadius = size.width / 10.0

        let positions = [
            CGPoint(x: size.width * 0.25, y: size.height * 0.66),
            CGPoint(x: size.width * 0.50, y: size.height * 0.66),
            CGPoint(x: size.width * 0.75, y: size.height * 0.66),
            CGPoint(x: size.width * 0.25, y: size.height * 0.33),
            CGPoint(x: size.width * 0.50, y: size.height * 0.33),
            CGPoint(x: size.width * 0.75, y: size.height * 0.33),
        ]

        for (i, position) in positions.enumerated() {
            let circleRect = NSRect(
                x: position.x - circleRadius,
                y: position.y - circleRadius,
                width: circleRadius * 2,
                height: circleRadius * 2
            )
            colors[i].setFill()
            NSBezierPath(ovalIn: circleRect).fill()
        }

        image.unlockFocus()
        return image
    }
}

#Preview {
    GrayscalePreview()
}
