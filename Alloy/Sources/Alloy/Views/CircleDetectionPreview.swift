import SwiftUI
import AppKit

struct CircleDetectionPreview: View {
    @State private var minDiameter: Double = 15
    @State private var maxDiameter: Double = 60
    @State private var threshold: Double = 0.3
    @State private var correlationThreshold: Double = 0.5
    @State private var maxCircles: Double = 10
    @State private var showInverted: Bool = false
    @State private var usePeakFinding: Bool = true
    @State private var detectedCircles: [DetectedCircle] = []
    @State private var processingTime: Double = 0.0
    @State private var processedImage: NSImage?
    @State private var isProcessing: Bool = false
    @State private var originalImageCache: NSImage?
    @State private var hasLoggedOverlay = false

    private let imageSize: CGFloat = 256

    var body: some View {
        VStack {
            imageDisplaySection
                .padding(.bottom)
            
            controlsSection
        }
        .padding()
        .onAppear {
            if originalImageCache == nil {
                // Force image generation first time
                _ = originalImage
            }
            processImage()
        }
        .onChange(of: minDiameter) {
            if minDiameter >= maxDiameter {
                maxDiameter = min(150.0, minDiameter + 5.0)
            }
            processImage()
        }
        .onChange(of: maxDiameter) {
            if maxDiameter <= minDiameter {
                minDiameter = max(5.0, maxDiameter - 5.0)
            }
            processImage()
        }
        .onChange(of: threshold) {
            processImage()
        }
        .onChange(of: correlationThreshold) {
            processImage()
        }
        .onChange(of: maxCircles) {
            processImage()
        }
        .onChange(of: showInverted) {
            processImage()
        }
        .onChange(of: usePeakFinding) {
            processImage()
        }
    }
    
    // MARK: - Subviews
    
    private var imageDisplaySection: some View {
        VStack(spacing: 20) {
            originalImageView
            circleDetectionImageView
        }
    }
    
    private var originalImageView: some View {
        VStack {
            Text("Original")
                .font(.headline)
            Image(nsImage: originalImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: imageSize, height: imageSize)
                .border(Color.gray)
        }
    }
    
    private var circleDetectionImageView: some View {
        VStack {
            Text("Circle Detection")
                .font(.headline)
            
            Group {
                if let processedImage {
                    Image(nsImage: processedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: imageSize, height: imageSize)
                        .border(Color.gray)
                        .overlay(
                            GeometryReader { geometry in
                                circleOverlays(in: geometry)
                            }
                        )
                } else if isProcessing {
                    Rectangle()
                        .fill(Color.gray)
                        .frame(width: imageSize, height: imageSize)
                        .overlay(Text("Processing..."))
                } else {
                    Rectangle()
                        .fill(Color.gray)
                        .frame(width: imageSize, height: imageSize)
                        .overlay(Text("No image"))
                }
            }
        }
    }
    
    private func circleOverlays(in geometry: GeometryProxy) -> some View {
        let transform = calculateTransform(
            imageSize: originalImage.size,
            displaySize: geometry.size
        )
        
        // Debug output for transformation (only once ever)
        if !hasLoggedOverlay && !detectedCircles.isEmpty {
            print("[Overlay] Image size: \(originalImage.size), Display size: \(geometry.size)")
            print("[Overlay] Transform scale: \(transform.scale), offset: \(transform.offset)")
            hasLoggedOverlay = true
        }
        
        return ForEach(Array(detectedCircles.enumerated()), id: \.offset) { index, circle in
            // Convert from Metal coordinates (Y=0 at bottom) to SwiftUI (Y=0 at top)
            let flippedY = originalImage.size.height - CGFloat(circle.y)
            
            let scaledX = CGFloat(circle.x) * transform.scale + transform.offset.x
            let scaledY = flippedY * transform.scale + transform.offset.y
            let scaledDiameter = CGFloat(circle.diameter) * transform.scale
            
            // Clamp coordinates to stay within the displayed image bounds
            let actualImageWidth = originalImage.size.width * transform.scale
            let actualImageHeight = originalImage.size.height * transform.scale
            
            let clampedX = max(transform.offset.x, min(scaledX, transform.offset.x + actualImageWidth))
            let clampedY = max(transform.offset.y, min(scaledY, transform.offset.y + actualImageHeight))
            
            // Debug output for first few circles (only first time)
            let _ = {
                if !hasLoggedOverlay && index < 3 {
                    print("[Overlay] Circle \(index + 1): original(\(circle.x),\(circle.y)) -> flipped(\(Int(CGFloat(circle.x))),\(Int(flippedY))) -> scaled(\(Int(scaledX)),\(Int(scaledY))) -> clamped(\(Int(clampedX)),\(Int(clampedY)))")
                }
            }()
            
            ZStack {
                Circle()
                    .stroke(Color.red, lineWidth: 2)
                    .frame(width: scaledDiameter, height: scaledDiameter)
                    .position(x: clampedX, y: clampedY)
                
                Text("\(index + 1)")
                    .font(.caption)
                    .foregroundColor(.red)
                    .background(Color.white.opacity(0.7))
                    .position(
                        x: clampedX,
                        y: clampedY - scaledDiameter / 2 - 12
                    )
            }
        }
    }
    
    private var controlsSection: some View {
        Form {
            detectionMethodSection
            detectionParametersSection
            preprocessingSection
            resultsSection
        }
        .padding()
        .frame(maxWidth: 400)
        .monospacedDigit()
    }
    
    private var detectionMethodSection: some View {
        Section("Detection Method") {
            Picker("Detection Algorithm", selection: $usePeakFinding) {
                Text("Peak Finding (Template Matching)").tag(true)
                Text("Sobel Edge Detection").tag(false)
            }
            .pickerStyle(.segmented)
        }
    }
    
    private var detectionParametersSection: some View {
        Section("Detection Parameters") {
            VStack(alignment: .leading, spacing: 8) {
                Slider(value: $minDiameter, in: 5.0...100.0, step: 1.0) {
                    Text("Min Diameter: \(Int(minDiameter))")
                }
                
                Slider(value: $maxDiameter, in: 10.0...150.0, step: 1.0) {
                    Text("Max Diameter: \(Int(maxDiameter))")
                }
                
                if usePeakFinding {
                    Slider(value: $correlationThreshold, in: 0.3...1.0, step: 0.05) {
                        Text("Match Quality: \(correlationThreshold, specifier: "%.2f")")
                    }
                    .help("How well the template must match (0.3 = loose, 1.0 = perfect match)")
                } else {
                    Slider(value: $threshold, in: 0.1...1.0, step: 0.05) {
                        Text("Edge Threshold: \(threshold, specifier: "%.2f")")
                    }
                }
                
                Slider(value: $maxCircles, in: 10.0...200.0, step: 10.0) {
                    Text("Max Circles: \(Int(maxCircles))")
                }
            }
        }
    }
    
    private var preprocessingSection: some View {
        Section("Preprocessing") {
            Toggle("Invert Image", isOn: $showInverted)
                .help("Invert colors before detection (useful for light circles on dark background)")
        }
    }
    
    private var resultsSection: some View {
        Section("Results") {
            VStack(alignment: .leading, spacing: 4) {
                Text("Detected Circles: \(detectedCircles.count)")
                    .font(.headline)
                
                Text("Processing Time: \(processingTime, specifier: "%.1f") ms")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if !detectedCircles.isEmpty {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(detectedCircles.enumerated()), id: \.offset) { index, circle in
                                HStack {
                                    Text("\(index + 1):")
                                        .foregroundColor(.red)
                                        .font(.caption)
                                    Text("(\(Int(circle.x)), \(Int(circle.y))) ⌀\(Int(circle.diameter))")
                                        .font(.caption)
                                    Spacer()
                                    Text("conf: \(circle.confidence, specifier: "%.2f")")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 100)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private struct ImageTransform {
        let scale: CGFloat
        let offset: CGPoint
    }
    
    private func calculateTransform(imageSize: CGSize, displaySize: CGSize) -> ImageTransform {
        // Calculate how the image is actually displayed within the frame
        let imageAspect = imageSize.width / imageSize.height
        let displayAspect = displaySize.width / displaySize.height
        
        let scale: CGFloat
        let offset: CGPoint
        
        if imageAspect > displayAspect {
            // Image is wider - fit to width
            scale = displaySize.width / imageSize.width
            let scaledHeight = imageSize.height * scale
            offset = CGPoint(x: 0, y: (displaySize.height - scaledHeight) / 2)
        } else {
            // Image is taller - fit to height
            scale = displaySize.height / imageSize.height
            let scaledWidth = imageSize.width * scale
            offset = CGPoint(x: (displaySize.width - scaledWidth) / 2, y: 0)
        }
        
        return ImageTransform(scale: scale, offset: offset)
    }

    private var originalImage: NSImage {
        if let cached = originalImageCache {
            return cached
        }
        let image = Self.generateTestImageWithCircles(size: NSSize(width: imageSize, height: imageSize))
        originalImageCache = image
        return image
    }

    private func processImage() {
        guard !isProcessing else { return }
        
        isProcessing = true
        detectedCircles = []
        processingTime = 0
        
        Task {
            print("[ProcessImage] NSImage size: \(self.originalImage.size)")
            
            // Create a properly sized bitmap context to avoid Retina scaling issues
            let width = Int(self.imageSize)
            let height = Int(self.imageSize)
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

            guard let context else {
                DispatchQueue.main.async {
                    self.isProcessing = false
                }
                return
            }
            
            // Draw the NSImage into our controlled context
            context.saveGState()
            context.scaleBy(x: 1.0, y: -1.0) // Flip Y coordinate
            context.translateBy(x: 0, y: -CGFloat(height))
            
            let nsGraphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = nsGraphicsContext
            
            self.originalImage.draw(in: NSRect(x: 0, y: 0, width: width, height: height))
            
            NSGraphicsContext.restoreGraphicsState()
            context.restoreGState()
            
            print("[ProcessImage] Context size: \(width)x\(height)")
            
            // Debug: Check a few pixel values to see if image data is correct
            let pixelData = data.withUnsafeBytes { bytes in
                return bytes.bindMemory(to: UInt8.self)
            }
            print("[ProcessImage] Sample pixels at key positions:")
            // Check center of first expected circle at (51, 179) -> (51, 76) in flipped coords
            let centerX = 51, centerY = 76
            let centerIndex = (centerY * width + centerX) * 4
            if centerIndex + 3 < data.count {
                let r = pixelData[centerIndex]
                let g = pixelData[centerIndex + 1] 
                let b = pixelData[centerIndex + 2]
                let a = pixelData[centerIndex + 3]
                print("  Expected circle center (\(centerX),\(centerY)): RGBA(\(r),\(g),\(b),\(a))")
            }
            
            // Check background at (10, 10)
            let bgIndex = (10 * width + 10) * 4
            if bgIndex + 3 < data.count {
                let r = pixelData[bgIndex]
                let g = pixelData[bgIndex + 1]
                let b = pixelData[bgIndex + 2] 
                let a = pixelData[bgIndex + 3]
                print("  Background (10,10): RGBA(\(r),\(g),\(b),\(a))")
            }

            do {
                guard let engine = CommonMetalEngine() else {
                    DispatchQueue.main.async {
                        self.isProcessing = false
                    }
                    return
                }
                
                let startTime = CFAbsoluteTimeGetCurrent()
                
                let configuredEngine = try engine
                    .withRGBAData(width: width, height: height)
                    .grayscale(strategy: .weighted)
                
                let finalEngine = self.showInverted ? try configuredEngine.invert() : configuredEngine
                
                let result: CircleDetectionResult
                if self.usePeakFinding {
                    result = try await finalEngine.executeWithPeakCircleDetection(
                        data: data,
                        minDiameter: Int(self.minDiameter),
                        maxDiameter: Int(self.maxDiameter),
                        correlationThreshold: Float(self.correlationThreshold),
                        maxPeaks: Int(self.maxCircles)
                    )
                } else {
                    result = try finalEngine.executeWithCircleDetection(
                        data: data,
                        minDiameter: Int(self.minDiameter),
                        maxDiameter: Int(self.maxDiameter),
                        threshold: Float(self.threshold),
                        maxCircles: Int(self.maxCircles)
                    )
                }
                
                let endTime = CFAbsoluteTimeGetCurrent()
                
                DispatchQueue.main.async {
                    self.detectedCircles = result.detectedCircles
                    self.processingTime = (endTime - startTime) * 1000 // Convert to milliseconds
                    self.processedImage = result.nsImage
                    self.isProcessing = false
                    
                    // Debug output
                    let methodName = self.usePeakFinding ? "Peak Finding" : "Sobel Edge"
                    print("[\(methodName)] Image size: \(width)x\(height)")
                    print("[\(methodName)] Detected \(result.detectedCircles.count) circles:")
                    for (index, circle) in result.detectedCircles.enumerated() {
                        print("  \(index + 1): x=\(circle.x), y=\(circle.y), diameter=\(circle.diameter), confidence=\(circle.confidence)")
                    }
                }
                
            } catch {
                print("Error processing image: \(error)")
                DispatchQueue.main.async {
                    self.detectedCircles = []
                    self.processingTime = 0
                    self.processedImage = nil
                    self.isProcessing = false
                }
            }
        }
    }

    static func generateTestImageWithCircles(size: NSSize) -> NSImage {
        // Create bitmap directly to ensure proper rendering
        let width = Int(size.width)
        let height = Int(size.height)
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

        guard let context else {
            // Fallback to empty image
            return NSImage(size: size)
        }

        // Black background
        context.setFillColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        context.fill(CGRect(origin: .zero, size: CGSize(width: width, height: height)))

        // Create filled circles (discs) of various sizes for testing
        let circles = [
            (center: CGPoint(x: size.width * 0.2, y: size.height * 0.7), radius: 15.0),
            (center: CGPoint(x: size.width * 0.5, y: size.height * 0.8), radius: 20.0),
            (center: CGPoint(x: size.width * 0.8, y: size.height * 0.6), radius: 12.0),
            (center: CGPoint(x: size.width * 0.3, y: size.height * 0.4), radius: 25.0),
            (center: CGPoint(x: size.width * 0.7, y: size.height * 0.3), radius: 18.0),
            (center: CGPoint(x: size.width * 0.15, y: size.height * 0.25), radius: 14.0),
            (center: CGPoint(x: size.width * 0.85, y: size.height * 0.85), radius: 16.0),
        ]

        // Debug output: Expected circle positions (only once)
        print("[Test Image] Generated with expected circles at:")
        for (index, circle) in circles.enumerated() {
            print("  \(index + 1): x=\(circle.center.x), y=\(circle.center.y), diameter=\(circle.radius * 2)")
        }

        // Draw filled white circles (discs)
        context.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        for circle in circles {
            let circleRect = CGRect(
                x: circle.center.x - circle.radius,
                y: circle.center.y - circle.radius,
                width: circle.radius * 2,
                height: circle.radius * 2
            )
            context.fillEllipse(in: circleRect)
        }

        // Add some deterministic noise/distraction elements (no randomness)
        context.setFillColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        let noiseElements = [
            (x: size.width * 0.1, y: size.height * 0.1, size: 3.0),
            (x: size.width * 0.9, y: size.height * 0.2, size: 2.5),
            (x: size.width * 0.6, y: size.height * 0.1, size: 3.5),
        ]
        
        for element in noiseElements {
            let rect = CGRect(x: element.x, y: element.y, width: element.size, height: element.size)
            context.fill(rect)
        }

        // Create CGImage and convert to NSImage
        guard let cgImage = context.makeImage() else {
            return NSImage(size: size)
        }
        
        let image = NSImage(cgImage: cgImage, size: size)
        
        // Save test image to disk for verification
        if let tiffData = image.tiffRepresentation,
           let bitmapRep = NSBitmapImageRep(data: tiffData),
           let pngData = bitmapRep.representation(using: .png, properties: [:]) {
            let url = URL(fileURLWithPath: "/tmp/test_circles.png")
            try? pngData.write(to: url)
            print("[Test Image] Saved to: \(url.path)")
        }
        
        return image
    }
}

#Preview {
    CircleDetectionPreview()
} 
