# Alloy

A Swift Metal framework for GPU-accelerated image processing. Chain shader operations with a builder pattern to build computer vision pipelines that run entirely on the GPU.

Zero external dependencies. macOS 14.0+. Swift 5.9+.

## Usage

```swift
import Alloy

// Initialize the engine
guard let engine = CommonMetalEngine() else { return }

// Process raw Bayer sensor data
let result = try engine
    .withRawData(width: 1024, height: 1024, bitDepth: 16)
    .debayerRGGB()
    .grayscale(strategy: .luminance)
    .blur(radius: 3)
    .execute(data: rawSensorData)

// Or start from RGBA data
let cropped = try engine
    .withRGBAData(width: 512, height: 512)
    .squareCrop(center: (x: 256, y: 256), sideLength: 200)
    .donutMask(innerRadius: 20)
    .execute(data: rgbaData)

// Access results
let texture = result.texture
let image = result.asNSImage()
```

## Shader Operations

| Operation | Description |
|---|---|
| **Debayer** | RGGB Bayer pattern demosaicing (8-bit and 16-bit) |
| **Grayscale** | Luminance conversion with 8 strategies |
| **Blur** | Gaussian blur with configurable radius |
| **Erosion** | Morphological erosion (4 or 8-connectivity, 1-20 iterations) |
| **Invert** | Color inversion |
| **Noise** | Random noise injection |
| **Peak Detection** | Local intensity maxima detection with threshold filtering |
| **Square Crop** | Region extraction around a center point |
| **Donut Mask** | Circular mask with configurable inner/outer radii |
| **HSV Position** | HSV-to-position mapping for visualization |
| **Color Sampling** | GPU-accelerated color extraction at arbitrary positions |
| **Connected Components** | Blob detection with centroid calculation |

## Installation

Add as a Swift Package dependency:

```swift
.package(path: "../alloy/Alloy")
```

Then add `"Alloy"` to your target's dependencies.

## Architecture

- **CommonMetalEngine** -- Builder-pattern entry point that chains operations and manages execution
- **MetalEngine** -- Base class handling Metal device, command queue, and pipeline state caching
- **ShaderOperation** -- Protocol each GPU operation conforms to
- **Metal shaders** -- 12 compute kernels in `Sources/Alloy/Shaders/`

Each operation has three parts: a parameter model (`Models/`), a Metal compute kernel (`Shaders/`), and a Swift builder extension (`Extensions/`).

## Building

```bash
cd Alloy
swift build
swift test
```

## License

Private repository.
