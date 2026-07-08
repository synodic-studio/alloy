# Alloy

A Swift Metal framework for GPU-accelerated image processing. Chain shader operations with a builder pattern to build computer vision pipelines that run entirely on the GPU.

Zero external dependencies. macOS 14.0+. Swift 5.9+.

An experimental **phantom-typed pipeline** layers compile-time stage safety over the engine, so invalid orderings (eroding before thresholding, debayering RGBA) fail to compile instead of producing silent garbage at runtime — see [Type-Safe Pipelines](#type-safe-pipelines-phantom-types).

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

## Type-Safe Pipelines (phantom types)

> **Experimental.** A typed frontend over `CommonMetalEngine`. Additive — the untyped builder above is unchanged.

`Pipeline<State>` carries the *semantic kind* of the image (`ColorImage`, `Binary`, …) in a **phantom type parameter** — an uninhabited marker that exists only at compile time. Each operation is offered *only* in a constrained extension where the state permits it, so misordered stages are a compile error, not a runtime surprise:

```swift
let blobs = try Pipeline
    .rgba(width: 512, height: 512)   // Pipeline<ColorImage>
    .blackAndWhite(threshold: 0.5)   // Pipeline<Binary>  — thresholding unlocks binary ops
    .erosion(iterations: 2)          // Pipeline<Binary>  — offered only where State: BlackAndWhite
    .connectedComponents(on: frameData, maxComponents: 20)   // terminal: [ComponentCentroid]
```

Erode before you threshold and it simply won't build:

```swift
Pipeline.rgba(width: 512, height: 512)
    .erosion(iterations: 1)
// error: referencing instance method 'erosion' on 'Pipeline'
//        requires that 'ColorImage' conform to 'BlackAndWhite'
```

The state markers (`ImageState`, `BlackAndWhite`, `Binary`) are the constraint vocabulary; a new state that should be erodable just conforms to `BlackAndWhite` and gains `erosion` for free. Compile-time rejection is guarded by `scripts/check-compile-fixtures.sh` (SPM can't assert compile *failures* in a test target). Design rationale and the full migration plan live in [`docs/pipeline-type-safety.md`](docs/pipeline-type-safety.md).

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
