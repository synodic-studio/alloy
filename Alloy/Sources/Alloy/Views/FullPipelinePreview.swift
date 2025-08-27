import AppKit
import SwiftUI

struct FullPipelinePreview: View {
    // MARK: - State

    // Erosion
    @State private var erosionIterations: Double = 9
    @State private var connectivity: ErosionConnectivity = .eight

    // For image generation (from ErosionPreview)
    @State private var capsuleRadius: Double = 7
    @State private var elongationPerStep: Double = 5

    // Noise
    @State private var noiseMagnitude: Double = 0.01
    @State private var noiseSeed: UInt32 = 42
    @State private var ignoreBlack: Bool = false
    @State private var ignoreWhite: Bool = false

    /// Blur
    @State private var blurRadius: Double = 10.0

    // Peak Detection
    @State private var peakThreshold: Double = 0.5
    @State private var neighborhoodSize: Double = 3.0
    @State private var minDistance: Double = 3.0
    @State private var maxPeaks: Double = 20.0

    // Results
    @State private var detectedPeaks: [DetectedPeak] = []
    @State private var originalImage: NSImage?
    @State private var processedImage: NSImage?

    // Image sizing
    private let displaySize: CGFloat = 280
    private var sourceImageWidth: CGFloat { 220 }
    private var sourceImageHeight: CGFloat { 220 }

    var body: some View {
        VStack {
            imageComparison
            controls
        }
        .padding()
        .onAppear(perform: runPipeline)
        .onChange(of: erosionIterations) { _, _ in runPipeline() }
        .onChange(of: connectivity) { _, _ in runPipeline() }
        .onChange(of: capsuleRadius) { _, _ in runPipeline() }
        .onChange(of: elongationPerStep) { _, _ in runPipeline() }
        .onChange(of: noiseMagnitude) { _, _ in runPipeline() }
        .onChange(of: noiseSeed) { _, _ in runPipeline() }
        .onChange(of: ignoreBlack) { _, _ in runPipeline() }
        .onChange(of: ignoreWhite) { _, _ in runPipeline() }
        .onChange(of: blurRadius) { _, _ in runPipeline() }
        .onChange(of: peakThreshold) { _, _ in runPipeline() }
        .onChange(of: neighborhoodSize) { _, _ in runPipeline() }
        .onChange(of: minDistance) { _, _ in runPipeline() }
        .onChange(of: maxPeaks) { _, _ in runPipeline() }
    }

    // MARK: - Image Views

    private var imageComparison: some View {
        HStack(spacing: 20) {
            imageDisplay(title: "Original", image: originalImage)
            imageDisplay(
                title: "Processed (\(detectedPeaks.count) peaks)",
                image: processedImage,
                showPeaks: true,
            )
        }
    }

    private func imageDisplay(
        title: String,
        image: NSImage?,
        showPeaks: Bool = false
    ) -> some View {
        VStack {
            Text(title)
                .font(.headline)

            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: displaySize, height: displaySize)
                    .border(Color.gray)
                    .overlay {
                        if showPeaks {
                            peakOverlay
                        }
                    }
            } else {
                Rectangle()
                    .fill(Color.gray)
                    .frame(width: displaySize, height: displaySize)
                    .overlay(Text("Loading..."))
            }
        }
    }

    private var peakOverlay: some View {
        GeometryReader { geometry in
            // The image is displayed using .scaledToFit, so we need to calculate the
            // actual rendered size to scale the peak coordinates correctly.
            let renderedFrame = self.calculateRenderedFrame(in: geometry)

            // The peak coordinates are in the coordinate space of the processed
            // image texture. We need to use its dimensions, not the source
            // image's point-based dimensions, for correct scaling.
            if let processedCGImage = self.processedImage?.cgImage(
                forProposedRect: nil,
                context: nil,
                hints: nil,
            ) {
                let imagePixelWidth = CGFloat(processedCGImage.width)
                let imagePixelHeight = CGFloat(processedCGImage.height)

                ForEach(Array(self.detectedPeaks.enumerated()), id: \.offset) { _, peak in
                    let scaledX = (CGFloat(peak.x) * renderedFrame.width / imagePixelWidth) + renderedFrame.origin.x
                    let scaledY = (CGFloat(peak.y) * renderedFrame.height / imagePixelHeight) + renderedFrame.origin.y

                    ZStack {
                        Circle()
                            .stroke(Color.red, lineWidth: 1)
                            .frame(width: 8, height: 8)

                        Text(String(format: "%.1f", peak.value))
                            .font(.system(size: 8))
                            .foregroundColor(.yellow)
                            .offset(y: -10)
                    }
                    .position(x: scaledX, y: scaledY)
                }
            }
        }
    }

    private func calculateRenderedFrame(in geometry: GeometryProxy) -> CGRect {
        let sourceAspectRatio = sourceImageWidth / sourceImageHeight
        let viewAspectRatio = geometry.size.width / geometry.size.height

        let renderedSize = if sourceAspectRatio > viewAspectRatio {
            // Letterboxed (limited by width)
            CGSize(
                width: geometry.size.width,
                height: geometry.size.width / sourceAspectRatio,
            )
        } else {
            // Pillarboxed (limited by height)
            CGSize(
                width: geometry.size.height * sourceAspectRatio,
                height: geometry.size.height,
            )
        }

        let origin = CGPoint(
            x: (geometry.size.width - renderedSize.width) / 2,
            y: (geometry.size.height - renderedSize.height) / 2,
        )

        return CGRect(origin: origin, size: renderedSize)
    }

    // MARK: - Controls

    private var controls: some View {
        ScrollView {
            controlsContent
        }
        .frame(maxWidth: 400)
        .frame(height: 1000)
        .monospacedDigit()
    }

    private var controlsContent: some View {
        VStack(alignment: .leading) {
            Group {
                Text("Source Image").font(.headline)
                controlSlider(label: "Capsule Radius", value: $capsuleRadius, range: 3 ... 12, step: 1)
                controlSlider(label: "Elongation", value: $elongationPerStep, range: 0 ... 20, step: 1)
            }

            Divider()

            Group {
                Text("Erosion").font(.headline)
                controlSlider(label: "Iterations", value: $erosionIterations, range: 1 ... 20, step: 1)
                Picker("Connectivity:", selection: $connectivity) {
                    ForEach(ErosionConnectivity.allCases, id: \.self) { connectivity in
                        Text(connectivity.displayName).tag(connectivity)
                    }
                }
                .pickerStyle(.segmented)
            }

            Divider()

            Group {
                Text("Noise").font(.headline)
                controlSlider(label: "Magnitude", value: $noiseMagnitude, range: 0 ... 0.5, step: 0.01)
                Toggle("Ignore Black Pixels", isOn: $ignoreBlack)
                Toggle("Ignore White Pixels", isOn: $ignoreWhite)
            }

            Divider()

            Group {
                Text("Blur").font(.headline)
                controlSlider(label: "Radius", value: $blurRadius, range: 0.5 ... 15.0, step: 0.1)
            }

            Divider()

            Group {
                Text("Peak Detection").font(.headline)
                controlSlider(label: "Threshold", value: $peakThreshold, range: 0.0 ... 1.0, step: 0.05)
                controlSlider(label: "Min Distance", value: $minDistance, range: 1 ... 20, step: 1)
                controlSlider(label: "Max Peaks", value: $maxPeaks, range: 1 ... 100, step: 1)
                HStack {
                    Text("Neighborhood")
                        .frame(width: 100, alignment: .leading)
                    Slider(value: $neighborhoodSize, in: 3 ... 25, step: 2)
                    Text(String(format: "%.0f", neighborhoodSize))
                        .frame(width: 50)
                }
            }
        }
        .padding()
    }

    private func controlSlider(
        label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double
    ) -> some View {
        HStack {
            Text(label)
                .frame(width: 100, alignment: .leading)
            Slider(value: value, in: range, step: step)
            Text(String(format: "%.2f", value.wrappedValue))
                .frame(width: 50)
        }
    }

    // MARK: - Image Generation and Peak Detection

    private func runPipeline() {
        let image = generateCapsulesImage()
        self.originalImage = image

        guard let originalImage = image,
              let cgImage = originalImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }

        let width = cgImage.width
        let height = cgImage.height
        let data = originalImage.rgbaData

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Engine for processing the image
                guard let imageEngine = CommonMetalEngine() else { return }
                let imageResult = try imageEngine
                    .withRGBAData(width: width, height: height)
                    .erosion(iterations: Int(erosionIterations), connectivity: connectivity)
                    .noise(magnitude: noiseMagnitude, seed: noiseSeed, ignoreBlack: ignoreBlack, ignoreWhite: ignoreWhite)
                    .blur(radius: blurRadius)
                    .execute(data: data)
                let finalImage = imageResult.texture.toNSImage(width: imageResult.width, height: imageResult.height)

                // Engine for detecting peaks
                guard let processedData = finalImage?.rgbaData,
                      let peakEngine = CommonMetalEngine()
                else {
                    DispatchQueue.main.async {
                        self.detectedPeaks = []
                        self.processedImage = finalImage
                    }
                    return
                }

                let peaks = try peakEngine
                    .withRGBAData(width: width, height: height)
                    .detectPeaks(
                        data: processedData,
                        neighborhoodSize: Int(neighborhoodSize),
                        minDistance: minDistance,
                        maxPeaks: Int(maxPeaks),
                        threshold: peakThreshold,
                    )

                DispatchQueue.main.async {
                    self.detectedPeaks = peaks
                    self.processedImage = finalImage
                }
            } catch {
                print("Error in pipeline: \(error)")
                DispatchQueue.main.async {
                    self.detectedPeaks = []
                    self.processedImage = nil
                }
            }
        }
    }

    private func calculateElongation(for index: Int) -> Double {
        Double(index) * elongationPerStep
    }

    private func generateCapsulesImage() -> NSImage? {
        let image = NSImage(size: NSSize(width: sourceImageWidth, height: sourceImageHeight))
        image.lockFocus()

        NSColor.black.setFill()
        NSRect(origin: .zero, size: NSSize(width: sourceImageWidth, height: sourceImageHeight)).fill()
        NSColor.white.setFill()

        let baseRadius = CGFloat(capsuleRadius)
        let positions = [
            CGPoint(x: sourceImageWidth * 0.2, y: sourceImageHeight * 0.7),
            CGPoint(x: sourceImageWidth * 0.5, y: sourceImageHeight * 0.7),
            CGPoint(x: sourceImageWidth * 0.8, y: sourceImageHeight * 0.7),
            CGPoint(x: sourceImageWidth * 0.2, y: sourceImageHeight * 0.3),
            CGPoint(x: sourceImageWidth * 0.5, y: sourceImageHeight * 0.3),
            CGPoint(x: sourceImageWidth * 0.8, y: sourceImageHeight * 0.3),
        ]

        for (i, position) in positions.enumerated() {
            let elongation = calculateElongation(for: i)
            let width = baseRadius * 2
            let height = baseRadius * 2 * CGFloat(1.0 + elongation / 100.0)
            let capsuleRect = NSRect(
                x: position.x - width / 2,
                y: position.y - height / 2,
                width: width,
                height: height,
            )
            let cornerRadius = width / 2
            let capsulePath = NSBezierPath(roundedRect: capsuleRect, xRadius: cornerRadius, yRadius: cornerRadius)
            capsulePath.fill()
        }

        image.unlockFocus()
        return image
    }
}

// MARK: - NSImage Helper

private extension NSImage {
    var rgbaData: Data {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return Data() }
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

        guard let context else { return Data() }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return data
    }
}

#Preview {
    FullPipelinePreview()
}
