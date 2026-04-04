import AppKit
import SwiftUI

struct PeakDetectionPreview: View {
    // MARK: - Test Image Types

    enum TestImage: String, CaseIterable, Identifiable {
        case singlePeak = "Single Peak"
        case multiplePeaks = "Multiple Peaks"
        case closePeaks = "Close Peaks"
        case edgePeaks = "Edge Peaks"
        case noisy = "Noisy Image"

        var id: String { self.rawValue }
    }

    // MARK: - State

    @State private var neighborhoodSize: Double = 3.0
    @State private var minDistance: Double = 3.0
    @State private var maxPeaks: Double = 20.0
    @State private var threshold: Double = 0.5

    @State private var detectedPeaks: [DetectedPeak] = []
    @State private var originalImage: NSImage?
    @State private var processedImage: NSImage?
    @State private var selectedTest: TestImage = .singlePeak

    private let imageSize: CGFloat = 128
    private let displaySize: CGFloat = 384

    var body: some View {
        VStack {
            imageComparison
            controls
        }
        .padding()
        .onAppear(perform: generateImageAndDetectPeaks)
        .onChange(of: neighborhoodSize) { _, _ in detectPeaksAsync() }
        .onChange(of: minDistance) { _, _ in detectPeaksAsync() }
        .onChange(of: maxPeaks) { _, _ in detectPeaksAsync() }
        .onChange(of: threshold) { _, _ in detectPeaksAsync() }
        .onChange(of: selectedTest) { _, _ in generateImageAndDetectPeaks() }
    }

    // MARK: - Image Views

    private var imageComparison: some View {
        VStack(spacing: 20) {
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
            ForEach(Array(detectedPeaks.enumerated()), id: \.offset) { _, peak in
                let scaledX = CGFloat(peak.x) * geometry.size.width / imageSize
                let scaledY = CGFloat(peak.y) * geometry.size.height / imageSize

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

    // MARK: - Controls

    private var controls: some View {
        VStack {
            Picker("Test Image:", selection: $selectedTest) {
                ForEach(TestImage.allCases) { test in
                    Text(test.rawValue).tag(test)
                }
            }
            .pickerStyle(.segmented)

            controlSlider(label: "Threshold", value: $threshold, range: 0.0 ... 1.0, step: 0.05)
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
        .padding()
        .frame(maxWidth: 400)
        .monospacedDigit()
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

    private func generateImageAndDetectPeaks() {
        let image = createTestImage(for: selectedTest)
        self.originalImage = image
        detectPeaksAsync()
    }

    private func createTestImage(for type: TestImage) -> NSImage {
        let width = Int(imageSize)
        let height = Int(imageSize)
        var data = Data(count: height * width * 4)

        data.withUnsafeMutableBytes { rawPtr in
            let pixels = rawPtr.bindMemory(to: UInt8.self)
            for i in stride(from: 0, to: pixels.count, by: 4) {
                pixels[i] = 0
                pixels[i + 1] = 0
                pixels[i + 2] = 0
                pixels[i + 3] = 255
            }
        }

        switch type {
        case .singlePeak:
            addPeak(to: &data, x: 64, y: 64, brightness: 255, width: width)
        case .multiplePeaks:
            addPeak(to: &data, x: 30, y: 30, brightness: 255, width: width)
            addPeak(to: &data, x: 90, y: 60, brightness: 200, width: width)
            addPeak(to: &data, x: 50, y: 100, brightness: 150, width: width)
        case .closePeaks:
            addPeak(to: &data, x: 60, y: 64, brightness: 255, width: width)
            addPeak(to: &data, x: 65, y: 64, brightness: 250, width: width)
        case .edgePeaks:
            addPeak(to: &data, x: 2, y: 64, brightness: 255, width: width)
            addPeak(to: &data, x: 125, y: 125, brightness: 200, width: width)
        case .noisy:
            for _ in 0 ..< 20 {
                addPeak(
                    to: &data,
                    x: .random(in: 0 ..< width),
                    y: .random(in: 0 ..< height),
                    brightness: .random(in: 50 ... 150),
                    width: width,
                )
            }
            addPeak(to: &data, x: 64, y: 64, brightness: 255, width: width) // A real peak
        }

        return NSImage.fromData(data: data, width: width, height: height) ?? NSImage()
    }

    private func addPeak(to data: inout Data, x: Int, y: Int, brightness: UInt8, width: Int) {
        guard x >= 0, x < width, y >= 0, y < width else { return }
        data.withUnsafeMutableBytes { rawPtr in
            let pixels = rawPtr.bindMemory(to: UInt8.self)
            let pixelIndex = (y * width + x) * 4
            pixels[pixelIndex] = brightness
            pixels[pixelIndex + 1] = brightness
            pixels[pixelIndex + 2] = brightness
            pixels[pixelIndex + 3] = 255
        }
    }

    private func detectPeaksAsync() {
        guard let originalImage,
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
                    .peakDetection(neighborhoodSize: Int(neighborhoodSize), threshold: threshold)
                    .execute(data: data)
                let finalImage = imageResult.texture.toNSImage(width: imageResult.width, height: imageResult.height)

                // Engine for detecting peaks
                guard let peakEngine = CommonMetalEngine() else { return }
                let peaks = try peakEngine
                    .withRGBAData(width: width, height: height)
                    .detectPeaks(
                        data: data,
                        neighborhoodSize: Int(neighborhoodSize),
                        minDistance: minDistance,
                        maxPeaks: Int(maxPeaks),
                        threshold: threshold,
                    )

                DispatchQueue.main.async {
                    self.detectedPeaks = peaks
                    self.processedImage = finalImage
                    print("Detected \(peaks.count) peaks.")
                }
            } catch {
                print("Error detecting peaks: \(error)")
                DispatchQueue.main.async {
                    self.detectedPeaks = []
                    self.processedImage = nil
                }
            }
        }
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

    static func fromData(data: Data, width: Int, height: Int) -> NSImage? {
        let bytesPerRow = width * 4
        let context = CGContext(
            data: UnsafeMutableRawPointer(mutating: (data as NSData).bytes),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue,
        )

        guard let context, let cgImage = context.makeImage() else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
    }
}

#Preview {
    PeakDetectionPreview()
}
