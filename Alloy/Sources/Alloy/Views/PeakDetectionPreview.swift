import SwiftUI
import AppKit

struct PeakDetectionPreview: View {
    @State private var neighborhoodSize: Int = 8
    @State private var detectedPeaks: [DetectedPeak] = []
    @State private var testImage: NSImage?
    
    private let imageSize: CGFloat = 32
    private let displaySize: CGFloat = 256

    var body: some View {
        VStack {
            imageComparison
            controls
        }
        .padding()
        .onAppear {
            createTestImageAndDetectPeaks()
        }
        .onChange(of: neighborhoodSize) {
            detectPeaksAsync()
        }
    }
    
    private var imageComparison: some View {
        VStack(spacing: 20) {
            originalImageView
            peakImageView
        }
    }
    
    private var originalImageView: some View {
        VStack {
            Text("Original")
                .font(.headline)
            if let testImage {
                Image(nsImage: testImage)
                    .resizable()
                    .interpolation(.none)
                    .frame(width: displaySize, height: displaySize)
                    .border(Color.gray)
            } else {
                Rectangle()
                    .fill(Color.gray)
                    .frame(width: displaySize, height: displaySize)
                    .overlay(Text("Loading..."))
            }
        }
    }
    
    private var peakImageView: some View {
        VStack {
            Text("Peak Detection (\(detectedPeaks.count) peaks)")
                .font(.headline)
            ZStack {
                if let testImage {
                    Image(nsImage: testImage)
                        .resizable()
                        .interpolation(.none)
                        .frame(width: displaySize, height: displaySize)
                        .border(Color.gray)
                        .overlay(
                            GeometryReader { geometry in
                                ForEach(Array(detectedPeaks.enumerated()), id: \.offset) { index, peak in
                                    let scaledX = CGFloat(peak.x) * geometry.size.width / imageSize
                                    let scaledY = CGFloat(peak.y) * geometry.size.height / imageSize
                                    
                                    ZStack {
                                        Circle()
                                            .stroke(Color.red, lineWidth: 2)
                                            .frame(width: 8, height: 8)
                                        
                                        Text(String(format: "%.2f,%.2f", peak.x, peak.y))
                                            .font(.system(size: 8))
                                            .foregroundColor(.yellow)
                                            .offset(x: 0, y: -12)
                                    }
                                    .position(x: scaledX + 4, y: scaledY + 4)
                                }
                            }
                        )
                } else {
                    Rectangle()
                        .fill(Color.gray)
                        .frame(width: displaySize, height: displaySize)
                        .overlay(Text("Loading..."))
                }
            }
        }
    }
    
    private var controls: some View {
        VStack {
            Picker("Neighborhood:", selection: $neighborhoodSize) {
                Text("8 neighbors").tag(8)
                Text("16 neighbors").tag(16)
            }
        }
        .padding()
        .frame(maxWidth: 300)
        .monospacedDigit()
    }

    private func createTestImageAndDetectPeaks() {
        let image = createTestImage()
        self.testImage = image
        detectPeaksAsync()
    }
    
    private func createTestImage() -> NSImage {
        // Create a simple test image directly with raw data to avoid coordinate confusion
        let width = Int(imageSize)
        let height = Int(imageSize)
        let bytesPerRow = width * 4
        var data = Data(count: height * bytesPerRow)
        
        // Fill with black background
        data.withUnsafeMutableBytes { rawPtr in
            let pixels = rawPtr.bindMemory(to: UInt8.self)
            for i in 0..<pixels.count {
                pixels[i] = 0
            }
        }
        
        // Add one bright pixel for simple testing (using Metal/SwiftUI coordinate system with (0,0) at top-left)
        let peakX = 16
        let peakY = 16
        let brightness: UInt8 = 255
        let middleGray: UInt8 = 128
        
        data.withUnsafeMutableBytes { rawPtr in
            let pixels = rawPtr.bindMemory(to: UInt8.self)
            
            // Add perimeter of middle gray pixels around the peak
            for dy in -1...1 {
                for dx in -1...1 {
                    let x = peakX + dx
                    let y = peakY + dy
                    
                    // Skip if out of bounds
                    if x < 0 || x >= width || y < 0 || y >= height { continue }
                    
                    // Skip the center pixel (we'll set it to bright white after)
                    if dx == 0 && dy == 0 { continue }
                    
                    let pixelIndex = (y * width + x) * 4
                    pixels[pixelIndex] = middleGray     // R
                    pixels[pixelIndex + 1] = middleGray // G
                    pixels[pixelIndex + 2] = middleGray // B
                    pixels[pixelIndex + 3] = 255        // A
                }
            }
            
            // Set the center peak pixel to bright white
            let pixelIndex = (peakY * width + peakX) * 4
            pixels[pixelIndex] = brightness     // R
            pixels[pixelIndex + 1] = brightness // G
            pixels[pixelIndex + 2] = brightness // B
            pixels[pixelIndex + 3] = 255        // A
            
            print("Placed single peak at (\(peakX), \(peakY)) with brightness \(brightness) surrounded by gray perimeter")
        }
        
        // Create NSImage from raw data
        let context = CGContext(
            data: data.withUnsafeMutableBytes { $0.baseAddress },
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        )
        
        guard let context, let cgImage = context.makeImage() else {
            return NSImage(size: NSSize(width: imageSize, height: imageSize))
        }
        
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: imageSize, height: imageSize))
        print("Created test image with dimensions: \(width)x\(height)")
        return nsImage
    }
    
    private func detectPeaksAsync() {
        guard let testImage, 
              let cgImage = testImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        
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
        
        guard let context else { return }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        do {
            guard let engine = CommonMetalEngine() else { return }
            print("Image dimensions: \(width)x\(height)")
            let peaks = try engine
                .withRGBAData(width: width, height: height)
                .detectPeaks(
                    data: data,
                    neighborhoodSize: neighborhoodSize,
                    minDistance: 3.0,
                    maxPeaks: 20
                )
            
            DispatchQueue.main.async {
                self.detectedPeaks = peaks
                print("Detected peaks: \(peaks.map { "(\($0.x), \($0.y))" }.joined(separator: ", "))")
            }
        } catch {
            print("Error detecting peaks: \(error)")
            DispatchQueue.main.async {
                self.detectedPeaks = []
            }
        }
    }
}

#Preview {
    PeakDetectionPreview()
} 
