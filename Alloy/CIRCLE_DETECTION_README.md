# Circle Detection and Image Invert Shaders

This document describes the new circle detection and image invert shaders added to the Alloy Metal engine.

## Image Invert Shader

The image invert shader inverts the RGB channels of an image while preserving the alpha channel.

### Usage

```swift
let engine = CommonMetalEngine()
let result = try engine
    .withRGBAData(width: imageWidth, height: imageHeight)
    .grayscale(strategy: .weighted)  // Optional: convert to grayscale first
    .invert()                        // Invert the image
    .execute(data: imageData)
```

### Use Cases
- Inverting images for better circle detection (light circles on dark background → dark circles on light background)
- General image processing effects
- Preprocessing for other computer vision tasks

## Circle Detection Shaders

Two different circle detection approaches are available, each optimized for different scenarios:

### 1. Peak Finding Circle Detection (Recommended)

Uses template matching with normalized cross-correlation for highly accurate detection of well-defined circles. This approach is inspired by your successful GravityWell implementation.

**Best for:** Well-defined, high-contrast circles with consistent shape and size.

### 2. Sobel Edge Detection 

Uses edge detection with a Hough Transform-like approach for general circle detection in various image conditions.

**Best for:** General purpose circle detection, noisy images, or circles with varying edge quality.

### Basic Usage

**Peak Finding (Recommended for well-defined circles):**
```swift
let engine = CommonMetalEngine()
let result = try engine
    .withRGBAData(width: imageWidth, height: imageHeight)
    .grayscale(strategy: .weighted)  // Convert to grayscale first
    .executeWithPeakCircleDetection(
        data: imageData,             // Input image data
        minDiameter: 10,             // Minimum circle diameter to detect
        maxDiameter: 50,             // Maximum circle diameter to detect  
        correlationThreshold: 0.7,   // Template correlation threshold (0.0-1.0)
        maxPeaks: 100                // Maximum number of peaks to detect
    )
```

**Sobel Edge Detection (General purpose):**
```swift
let engine = CommonMetalEngine()
let result = try engine
    .withRGBAData(width: imageWidth, height: imageHeight)
    .grayscale(strategy: .weighted)  // Convert to grayscale first
    .executeWithCircleDetection(
        data: imageData,     // Input image data
        minDiameter: 10,     // Minimum circle diameter to detect
        maxDiameter: 50,     // Maximum circle diameter to detect  
        threshold: 0.3,      // Edge detection threshold (0.0-1.0)
        maxCircles: 100      // Maximum number of circles to return
    )

// Access detected circles (same for both methods)
for circle in result.detectedCircles {
    print("Circle at (\(circle.x), \(circle.y)) with diameter \(circle.diameter)")
    print("Confidence: \(circle.confidence)")
}
```

### With Image Inversion

For images with light circles on dark backgrounds, you may want to invert first:

```swift
let result = try engine
    .withRGBAData(width: imageWidth, height: imageHeight)
    .grayscale(strategy: .weighted)
    .invert()                        // Invert for better detection
    .executeWithCircleDetection(
        data: imageData,
        minDiameter: 14,
        maxDiameter: 28,
        threshold: 0.4
    )
```

### Parameters

- **minDiameter**: Minimum circle diameter to detect (pixels)
- **maxDiameter**: Maximum circle diameter to detect (pixels)  
- **threshold**: Edge detection sensitivity (0.0-1.0, lower = more sensitive)
- **maxCircles**: Maximum number of circles to return (for performance)

### Return Value

The `executeWithCircleDetection` method returns a `CircleDetectionResult` containing:

- **texture**: The processed image (with edge detection visualization)
- **width/height**: Image dimensions
- **detectedCircles**: Array of `DetectedCircle` objects

Each `DetectedCircle` contains:
- **x, y**: Center coordinates
- **diameter**: Circle diameter in pixels
- **confidence**: Detection confidence score
- **radius**: Computed radius (diameter / 2)
- **center**: Center as a tuple (x, y)

### Performance Considerations

- Circle detection is computationally intensive
- For 400x400 images, detection typically takes 10-50ms on modern hardware
- Use appropriate min/max diameter ranges to reduce computation
- Consider preprocessing with grayscale conversion for best results
- The algorithm includes non-maximum suppression to reduce duplicate detections

### Best Practices

1. **Preprocessing**: Convert to grayscale first for consistent results
2. **Contrast**: Ensure good contrast between circles and background
3. **Parameter Tuning**: 
   - Start with threshold around 0.3-0.5
   - Adjust min/max diameter based on expected circle sizes
   - Use invert() if you have light circles on dark background
4. **Performance**: Limit maxCircles to reasonable numbers (50-200)

### Example for Ball Detection

Based on your use case (diameter 14 circles in 400x400-600x600 images):

```swift
let result = try engine
    .withRGBAData(width: imageWidth, height: imageHeight)
    .grayscale(strategy: .weighted)
    .executeWithCircleDetection(
        data: imageData,
        minDiameter: 10,     // Slightly below your target
        maxDiameter: 50,     // Allow for larger balls too
        threshold: 0.3,      // Good starting point
        maxCircles: 50       // Reasonable limit
    )

print("Detected \(result.circleCount) circles")
for (index, circle) in result.detectedCircles.enumerated() {
    print("Ball \(index + 1): center=(\(circle.x), \(circle.y)), diameter=\(circle.diameter)")
}
```

## Interactive Preview

A SwiftUI preview is available for testing and tuning circle detection parameters:

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        CircleDetectionPreview()
    }
}
```

The preview includes:
- **Real-time processing**: Adjust parameters and see results immediately
- **Visual feedback**: Detected circles are overlaid in red with numbered labels
- **Parameter controls**: Sliders for min/max diameter, threshold, and max circles
- **Preprocessing options**: Toggle for image inversion
- **Results display**: Shows circle count, processing time, and detailed circle information
- **Test image**: Generates a synthetic image with circles of various sizes for testing

This is especially useful for:
- Finding optimal parameters for your specific use case
- Understanding how different thresholds affect detection
- Visualizing the edge detection process
- Performance testing with different settings 