# Example Usage

This file demonstrates how to use the new circle detection and image invert shaders.

## Basic Example: Detecting Circles in an Image

```swift
import Alloy
import AppKit

func detectCirclesInImage() {
    // Load your image data (this example creates test data)
    let imageWidth = 400
    let imageHeight = 400
    let imageData = createTestImageData(width: imageWidth, height: imageHeight)
    
    do {
        // Create and configure the engine
        guard let engine = CommonMetalEngine() else {
            print("Failed to create Metal engine")
            return
        }
        
        // Process the image and detect circles
        let result = try engine
            .withRGBAData(width: imageWidth, height: imageHeight)
            .grayscale(strategy: .weighted)        // Convert to grayscale
            .executeWithCircleDetection(
                data: imageData,
                minDiameter: 10,                   // Looking for circles 10-50 pixels diameter
                maxDiameter: 50,
                threshold: 0.3,                    // Edge detection sensitivity
                maxCircles: 100                    // Maximum circles to find
            )
        
        // Print results
        print("Detected \(result.circleCount) circles:")
        for (index, circle) in result.detectedCircles.enumerated() {
            print("  \(index + 1). Center: (\(Int(circle.x)), \(Int(circle.y))), " +
                  "Diameter: \(Int(circle.diameter)), Confidence: \(circle.confidence)")
        }
        
        // Optionally save the processed image
        if let processedImage = result.nsImage {
            // Save or display the image with edge detection visualization
            saveImage(processedImage, to: "detected_circles.png")
        }
        
    } catch {
        print("Error processing image: \(error)")
    }
}
```

## Example with Image Inversion

For images with light circles on dark backgrounds, inversion can improve detection:

```swift
func detectLightCirclesOnDarkBackground() {
    let imageData = loadYourImageData() // Your image loading code here
    
    do {
        guard let engine = CommonMetalEngine() else { return }
        
        let result = try engine
            .withRGBAData(width: 400, height: 400)
            .grayscale(strategy: .weighted)
            .invert()                              // Invert colors first
            .executeWithCircleDetection(
                data: imageData,
                minDiameter: 14,                   // Your target ball size
                maxDiameter: 28,
                threshold: 0.4                     // Slightly higher threshold after inversion
            )
        
        processDetectionResults(result)
    } catch {
        print("Detection failed: \(error)")
    }
}
```

## SwiftUI Integration Example

```swift
import SwiftUI
import Alloy

struct CircleDetectionApp: View {
    @State private var detectedCircles: [DetectedCircle] = []
    @State private var isProcessing = false
    
    var body: some View {
        VStack {
            Text("Circle Detection Demo")
                .font(.title)
            
            // Show the interactive preview
            CircleDetectionPreview()
            
            // Or use your own image
            Button("Detect Circles in Custom Image") {
                detectCirclesInCustomImage()
            }
            .disabled(isProcessing)
            
            if !detectedCircles.isEmpty {
                List(detectedCircles.indices, id: \.self) { index in
                    let circle = detectedCircles[index]
                    Text("Circle \(index + 1): (\(Int(circle.x)), \(Int(circle.y))) ⌀\(Int(circle.diameter))")
                }
            }
        }
        .padding()
    }
    
    private func detectCirclesInCustomImage() {
        isProcessing = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Your detection logic here
                let result = try performCircleDetection()
                
                DispatchQueue.main.async {
                    self.detectedCircles = result.detectedCircles
                    self.isProcessing = false
                }
            } catch {
                DispatchQueue.main.async {
                    print("Error: \(error)")
                    self.isProcessing = false
                }
            }
        }
    }
}
```

## Helper Functions

```swift
// Example test image generation
func createTestImageData(width: Int, height: Int) -> Data {
    var data = Data(count: width * height * 4) // RGBA
    
    // Fill with black background
    for y in 0..<height {
        for x in 0..<width {
            let offset = (y * width + x) * 4
            data[offset] = 0     // R
            data[offset + 1] = 0 // G  
            data[offset + 2] = 0 // B
            data[offset + 3] = 255 // A
        }
    }
    
    // Add some white circles
    let circles = [
        (x: width / 4, y: height / 4, radius: 15),
        (x: 3 * width / 4, y: height / 4, radius: 20),
        (x: width / 2, y: 3 * height / 4, radius: 12)
    ]
    
    for circle in circles {
        drawCircle(in: &data, width: width, height: height, 
                  centerX: circle.x, centerY: circle.y, radius: circle.radius)
    }
    
    return data
}

private func drawCircle(in data: inout Data, width: Int, height: Int, 
                       centerX: Int, centerY: Int, radius: Int) {
    for y in max(0, centerY - radius)..<min(height, centerY + radius) {
        for x in max(0, centerX - radius)..<min(width, centerX + radius) {
            let dx = x - centerX
            let dy = y - centerY
            let distance = sqrt(Double(dx * dx + dy * dy))
            
            // Draw circle outline
            if distance >= Double(radius - 2) && distance <= Double(radius + 1) {
                let offset = (y * width + x) * 4
                data[offset] = 255     // R - white
                data[offset + 1] = 255 // G - white  
                data[offset + 2] = 255 // B - white
                data[offset + 3] = 255 // A
            }
        }
    }
}

// Save image helper
func saveImage(_ image: NSImage, to filename: String) {
    guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
          let imageData = NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:]),
          let documentsPath = FileManager.default.urls(for: .documentsDirectory, 
                                                      in: .userDomainMask).first else {
        print("Failed to save image")
        return
    }
    
    let fileURL = documentsPath.appendingPathComponent(filename)
    
    do {
        try imageData.write(to: fileURL)
        print("Image saved to: \(fileURL.path)")
    } catch {
        print("Failed to save image: \(error)")
    }
}
```

## Tips for Your Ball Detection Use Case

Based on your requirements (diameter 14 balls in 400x400-600x600 images):

```swift
func detectBalls(in imageData: Data, width: Int, height: Int) throws -> [DetectedCircle] {
    guard let engine = CommonMetalEngine() else { 
        throw NSError(domain: "MetalError", code: 1, userInfo: nil)
    }
    
    let result = try engine
        .withRGBAData(width: width, height: height)
        .grayscale(strategy: .weighted)
        // .invert() // Uncomment if you have light circles on dark background
        .executeWithCircleDetection(
            data: imageData,
            minDiameter: 10,       // Slightly below your target
            maxDiameter: 30,       // Allow for some variation
            threshold: 0.3,        // Start here, adjust based on your image contrast
            maxCircles: 50         // Reasonable limit for performance
        )
    
    return result.detectedCircles
}
``` 