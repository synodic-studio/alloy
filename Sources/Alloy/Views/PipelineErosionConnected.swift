import AppKit
import SwiftUI

struct PipelineErosionConnected: View {
    @State private var dotRadius: Double = 7
    @State private var elongationPerStep: Double = 5
    @State private var erosionIterations: Double = 5
    @State private var connectivity: ErosionConnectivity = .eight
    @State private var maxComponents: Double = 50
    @State private var maxPixelsPerBlob: Double = 100
    @State private var detectedCentroids: [ComponentCentroid] = []
    @State private var processedImageSize: CGSize = .zero

    private let imageWidth: CGFloat = 200
    private let imageHeight: CGFloat = 150
    private let sourceImageScale: CGFloat = 0.7

    var body: some View {
        VStack {
            VStack {
                Text("Erosion + Connected Components Analysis")
                    .font(.headline)

                if let processedImage {
                    Image(nsImage: processedImage)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(height: imageHeight * 1.5)
                        .overlay {
                            overlayDetectedCentroids
                        }
                } else {
                    Rectangle()
                        .fill(Color.gray)
                        .frame(width: imageWidth, height: imageHeight)
                        .overlay(Text("Processing..."))
                }
            }
            .padding(.bottom)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Connected Components Found:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("\(detectedCentroids.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }

                if !detectedCentroids.isEmpty {
                    Text("Sample Centroids: \(centroidsText)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
            }
            .frame(maxWidth: 450, alignment: .leading)
            .padding(.horizontal)

            Form {
                Section("Analysis Results") {
                    HStack {
                        Text("Total Components:")
                        Spacer()
                        Text("\(detectedCentroids.count)")
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }

                    if !detectedCentroids.isEmpty {
                        let avgPixelCount = detectedCentroids.map { Int($0.pixelCount) }.reduce(0, +) / detectedCentroids.count
                        HStack {
                            Text("Avg Pixels/Component:")
                            Spacer()
                            Text("\(avgPixelCount)")
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section("Input Generation") {
                    Slider(value: $dotRadius, in: 3.0 ... 15.0, step: 1.0) {
                        Text("Dot radius: \(Int(dotRadius))")
                    }

                    Slider(value: $elongationPerStep, in: 0.0 ... 20.0, step: 1.0) {
                        Text("Elongation per step: \(elongationPerStep, specifier: "%.1f")%")
                    }
                }

                Section("Erosion") {
                    Picker("Connectivity:", selection: $connectivity) {
                        ForEach(ErosionConnectivity.allCases, id: \.self) { connectivity in
                            Text(connectivity.displayName).tag(connectivity)
                        }
                    }

                    Slider(value: $erosionIterations, in: 1.0 ... 15.0, step: 1.0) {
                        Text("Erosion iterations: \(Int(erosionIterations))")
                    }
                }

                Section("Connected Components") {
                    Slider(value: $maxComponents, in: 10.0 ... 200.0, step: 10.0) {
                        Text("Max components: \(Int(maxComponents))")
                    }

                    Slider(value: $maxPixelsPerBlob, in: 20.0 ... 200.0, step: 10.0) {
                        Text("Max pixels per blob: \(Int(maxPixelsPerBlob))")
                    }
                }
            }
            .padding()
            .frame(maxWidth: 450)
            .monospacedDigit()
        }
        .padding()
    }

    private var overlayDetectedCentroids: some View {
        GeometryReader { geometry in
            ForEach(Array(detectedCentroids.enumerated()), id: \.offset) { index, centroid in
                // Safety check to prevent division by zero
                guard processedImageSize.width > 0, processedImageSize.height > 0 else {
                    return AnyView(EmptyView())
                }

                let scaledX = CGFloat(centroid.x) * geometry.size.width / processedImageSize.width
                let scaledY = CGFloat(centroid.y) * geometry.size.height / processedImageSize.height

                return AnyView(
                    ZStack {
                        Circle()
                            .stroke(lineWidth: 2)
                            .foregroundStyle(.yellow)
                            .frame(width: 8, height: 8)

                        Circle()
                            .stroke(lineWidth: 1)
                            .foregroundStyle(.red)
                            .frame(width: 8, height: 8)

                        Text("\(index + 1)")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                            .offset(y: -12)
                    }
                    .position(x: scaledX, y: scaledY),
                )
            }
        }
    }

    private var centroidsText: String {
        detectedCentroids.prefix(5).enumerated().map { index, centroid in
            "\(index + 1): (\(String(format: "%.1f", centroid.x)), \(String(format: "%.1f", centroid.y)))"
        }.joined(separator: ", ")
    }

    private var processedImage: NSImage? {
        guard let originalImage = generateDotsImage() else { return nil }

        guard let cgImage = originalImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
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

            // Apply erosion first
            let erosionResult = try engine
                .withRGBAData(width: width, height: height)
                .erosion(iterations: Int(erosionIterations), connectivity: connectivity)
                .execute(data: data)

            // Now apply connected components analysis directly with the texture
            guard let connectedEngine = CommonMetalEngine() else { return nil }
            let connectedResult = try connectedEngine
                .withRGBAData(width: width, height: height)
                .executeConnectedComponentsWithTexture(inputTexture: erosionResult.texture, maxComponents: Int(maxComponents), maxPixelsPerBlob: Int(maxPixelsPerBlob))

            // Update detected centroids
            DispatchQueue.main.async {
                self.detectedCentroids = connectedResult.centroids
                self.processedImageSize = CGSize(width: width, height: height)
            }

            return erosionResult.texture.toNSImage(width: width, height: height)

        } catch {
            return nil
        }
    }

    private func generateDotsImage() -> NSImage? {
        // Create lower resolution source image
        let sourceWidth = imageWidth * sourceImageScale
        let sourceHeight = imageHeight * sourceImageScale

        let image = NSImage(size: NSSize(width: sourceWidth, height: sourceHeight))
        image.lockFocus()

        // Fill with black background
        NSColor.black.setFill()
        NSRect(origin: .zero, size: NSSize(width: sourceWidth, height: sourceHeight)).fill()

        // Set white color for dots
        NSColor.white.setFill()

        let baseRadius = CGFloat(dotRadius) * sourceImageScale

        // Define positions for dots in a grid pattern with some variation
        let positions = generateDotPositions(
            sourceWidth: sourceWidth,
            sourceHeight: sourceHeight,
            baseRadius: baseRadius,
        )

        // Draw dots with varying elongation
        for (i, position) in positions.enumerated() {
            let elongation = calculateElongation(for: i)

            // Calculate dot dimensions - vertical elongation
            let width = baseRadius * 2
            let height = baseRadius * 2 * CGFloat(1.0 + elongation / 100.0)

            // Create proper dot shape (rounded rectangle)
            let dotRect = NSRect(
                x: position.x - width / 2,
                y: position.y - height / 2,
                width: width,
                height: height,
            )

            let cornerRadius = width / 2
            let dotPath = NSBezierPath(roundedRect: dotRect, xRadius: cornerRadius, yRadius: cornerRadius)
            dotPath.fill()
        }

        image.unlockFocus()
        return image
    }

    private func generateDotPositions(sourceWidth: CGFloat, sourceHeight: CGFloat, baseRadius _: CGFloat) -> [CGPoint] {
        // Simple 2x2 grid of 4 dots
        [
            CGPoint(x: sourceWidth * 0.3, y: sourceHeight * 0.3), // Top-left
            CGPoint(x: sourceWidth * 0.7, y: sourceHeight * 0.3), // Top-right
            CGPoint(x: sourceWidth * 0.3, y: sourceHeight * 0.7), // Bottom-left
            CGPoint(x: sourceWidth * 0.7, y: sourceHeight * 0.7), // Bottom-right
        ]
    }

    private func calculateElongation(for index: Int) -> Double {
        Double(index) * elongationPerStep
    }
}

#Preview {
    PipelineErosionConnected()
        .frame(height: 800)
}
