import AppKit
import SwiftUI

struct ErosionPreview: View {
    @State private var radius: Double = 7
    @State private var elongationPerStep: Double = 5
    @State private var erosionIterations: Double = 5
    @State private var connectivity: ErosionConnectivity = .eight

    private let imageWidth: CGFloat = 110
    private let imageHeight: CGFloat = 100 // 1/2 height for 2 rows
    private let sourceImageScale: CGFloat = 0.5 // Lower resolution for bigger pixels

    var body: some View {
        VStack {
            VStack {
                Text("Original")
                    .font(.headline)
                if let originalImage {
                    Image(nsImage: originalImage)
                        .resizable()
                        .interpolation(.none) // Pixelated scaling
                        .scaledToFit()
                        .frame(height: imageHeight * 1.5)
//                        .frame(width: imageWidth, height: imageHeight)
                        .border(Color.gray)
                } else {
                    Rectangle()
                        .fill(Color.gray)
                        .frame(width: imageWidth, height: imageHeight)
                        .overlay(Text("Error creating image"))
                }
            }
            .padding(.bottom)

            VStack {
                Text("After Erosion")
                    .font(.headline)
                ZStack(alignment: .top) {
                    if let erodedImage {
                        Image(nsImage: erodedImage)
                            .resizable()
                            .interpolation(.none) // Pixelated scaling
                            .scaledToFit()
                            .frame(height: imageHeight * 1.5)
                    } else {
                        Rectangle()
                            .fill(Color.gray)
                            .frame(width: imageWidth, height: imageHeight)
                            .overlay(Text("Error"))
                    }
                }
            }

            overlayElongationValues

            Form {
                Picker("Connectivity:", selection: $connectivity) {
                    ForEach(ErosionConnectivity.allCases, id: \.self) { connectivity in
                        Text(connectivity.displayName).tag(connectivity)
                    }
                }

                Slider(value: $radius, in: 3.0 ... 12.0, step: 1.0) {
                    Text("Radius: \(Int(radius))")
                }

                Slider(value: $elongationPerStep, in: 0.0 ... 20.0, step: 1.0) {
                    Text("Elongation per step: \(elongationPerStep, specifier: "%.1f")%")
                }

                Slider(value: $erosionIterations, in: 1.0 ... 20.0, step: 1.0) {
                    Text("Erosion iterations: \(Int(erosionIterations))")
                }
            }
            .padding()
            .frame(maxWidth: 450)
            .monospacedDigit()
        }
        .padding()
    }

    private var overlayElongationValues: some View {
        let sourceWidth = imageWidth * sourceImageScale
        let capsuleSpacingX = sourceWidth / 3.0 // Much tighter spacing (was /3.5)

        return VStack(spacing: 0) {
            // Top row
            HStack(spacing: 0) {
                ForEach(0 ..< 3, id: \.self) { index in
                    let elongation = calculateElongation(for: index)
                    let absoluteValue = CGFloat(radius) * 2.0 * CGFloat(1.0 + elongation / 100.0)

                    VStack(spacing: 2) {
                        Text("\(elongation, specifier: "%.1f")%")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                        Text("\(absoluteValue, specifier: "%.1f")")
                            .font(.system(size: 8, weight: .regular, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .frame(width: capsuleSpacingX * (imageWidth / sourceWidth))
                    .multilineTextAlignment(.center)
                }
            }

            // Bottom row
            HStack(spacing: 0) {
                ForEach(3 ..< 6, id: \.self) { index in
                    let elongation = calculateElongation(for: index)
                    let absoluteValue = CGFloat(radius) * 2.0 * CGFloat(1.0 + elongation / 100.0)

                    VStack(spacing: 2) {
                        Text("\(elongation, specifier: "%.1f")%")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                        Text("\(absoluteValue, specifier: "%.1f")")
                            .font(.system(size: 8, weight: .regular, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .frame(width: capsuleSpacingX * (imageWidth / sourceWidth))
                    .multilineTextAlignment(.center)
                }
            }
        }
        .frame(width: imageWidth)
    }

    private var originalImage: NSImage? {
        generateCapsulesImage()
    }

    private var erodedImage: NSImage? {
        guard let originalImage,
              let cgImage = originalImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            return nil
        }

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
                bitmapInfo: bitmapInfo,
            )
        }

        guard let context else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        do {
            guard let engine = CommonMetalEngine() else { return nil }
            return try engine
                .withRGBAData(width: width, height: height)
                .erosion(iterations: Int(erosionIterations), connectivity: connectivity)
                .executeToImage(data: data)
        } catch {
            print("Error processing image: \(error)")
            return nil
        }
    }

    private func calculateElongation(for index: Int) -> Double {
        Double(index) * elongationPerStep
    }

    private func generateCapsulesImage() -> NSImage? {
        // Create lower resolution source image
        let sourceWidth = imageWidth * sourceImageScale
        let sourceHeight = imageHeight * sourceImageScale

        let image = NSImage(size: NSSize(width: sourceWidth, height: sourceHeight))
        image.lockFocus()

        // Fill with black background
        NSColor.black.setFill()
        NSRect(origin: .zero, size: NSSize(width: sourceWidth, height: sourceHeight)).fill()

        // Set white color for capsules
        NSColor.white.setFill()

        let baseRadius = CGFloat(radius) * sourceImageScale

        // Define positions for 6 capsules (2 rows × 3 columns) with much tighter spacing
        let positions = [
            // Top row - much closer together
            CGPoint(x: sourceWidth * 0.2, y: sourceHeight * 0.7),
            CGPoint(x: sourceWidth * 0.5, y: sourceHeight * 0.7),
            CGPoint(x: sourceWidth * 0.8, y: sourceHeight * 0.7),
            // Bottom row - much closer together
            CGPoint(x: sourceWidth * 0.2, y: sourceHeight * 0.3),
            CGPoint(x: sourceWidth * 0.5, y: sourceHeight * 0.3),
            CGPoint(x: sourceWidth * 0.8, y: sourceHeight * 0.3),
        ]

        // Draw 6 capsules with proper capsule shape
        for (i, position) in positions.enumerated() {
            let elongation = calculateElongation(for: i)

            // Calculate capsule dimensions - vertical elongation
            let width = baseRadius * 2
            let height = baseRadius * 2 * CGFloat(1.0 + elongation / 100.0)

            // Create proper capsule shape (rounded rectangle with radius = width/2)
            let capsuleRect = NSRect(
                x: position.x - width / 2,
                y: position.y - height / 2,
                width: width,
                height: height,
            )

            // For a true capsule, the corner radius should be half the width
            let cornerRadius = width / 2
            let capsulePath = NSBezierPath(roundedRect: capsuleRect, xRadius: cornerRadius, yRadius: cornerRadius)
            capsulePath.fill()
        }

        image.unlockFocus()
        return image
    }
}

#Preview {
    ErosionPreview()
}
