import SwiftUI
import AppKit

struct BlackAndWhitePreview: View {
    @State private var threshold: Double = 0.5

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
                Text("Black & White")
                    .font(.headline)
                if let blackAndWhiteImage {
                    Image(nsImage: blackAndWhiteImage)
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
                Slider(value: $threshold, in: 0.0...1.0) {
                    Text("Threshold: \(threshold, specifier: "%.2f")")
                }
            }
            .padding()
            .frame(maxWidth: 300)
            .monospacedDigit()
        }
        .padding()
    }

    private var originalImage: NSImage {
        return Self.generateTestImage(size: NSSize(width: imageSize, height: imageSize))
    }

    private var blackAndWhiteImage: NSImage? {
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
                .blackAndWhite(threshold: threshold)
                .executeToImage(data: data)
        } catch {
            print("Error processing image: \(error)")
            return nil
        }
    }

    static func generateTestImage(size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()

        // Create a horizontal gradient from black to white
        let gradient = NSGradient(starting: NSColor.black, ending: NSColor.white)
        let rect = NSRect(origin: .zero, size: size)
        gradient?.draw(in: rect, angle: 0.0) // 0 degrees = horizontal

        image.unlockFocus()
        return image
    }
}

#Preview {
    BlackAndWhitePreview()
} 