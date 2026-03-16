# Product Requirements Document: MetalAlloy Shader Chaining API

## Introduction/Overview

MetalAlloy is a Swift-first GPU processing library that solves the critical problem of making Metal shader development accessible to Swift and SwiftUI developers. Currently, developers struggle with complex Metal workflows, excessive boilerplate code, and poor compile-time safety when building image processing pipelines. 

This PRD defines a new chaining API that enables developers to chain blazing-fast Metal kernels with Swift-style ergonomics and compile-time guarantees, reducing development time by 50% while maintaining ≥30 fps performance.

**Core Value Proposition:** *Chain blazing-fast Metal kernels with Swift-style ergonomics and compile-time guarantees.*

## Goals

1. **Performance Goal:** Achieve ≥30 fps on M1 MacBook Air for typical image processing pipelines (60 fps is stellar)
2. **Developer Experience Goal:** Enable developers to build a 5-step shader pipeline in <10 minutes  
3. **Extensibility Goal:** Allow adding custom third-party shaders with ≤40 lines of code
4. **Safety Goal:** Catch all shader chain incompatibilities at compile-time via protocols & generics
5. **Migration Goal:** Internal team migrates from old API in <1 day with manual refactor of ~12 call sites

## User Stories

### Primary User Stories

**As an iOS/macOS app developer doing image processing,**  
I want to chain multiple GPU operations with SwiftUI-like syntax,  
So that I can build complex pipelines without writing Metal boilerplate code.

**As a Swift developer unfamiliar with Metal,**  
I want compile-time guarantees that my shader chains are valid,  
So that I don't spend hours debugging GPU pipeline errors at runtime.

**As a developer building camera/vision apps,**  
I want to add custom image processing effects quickly,  
So that I can prototype new features and get them to production fast.

**As a performance-conscious developer,**  
I want my GPU pipelines to automatically optimize without manual intervention,  
So that I can focus on features rather than performance tuning.

### Secondary User Stories

**As a library consumer,**  
I want to tap intermediate results with callback functions in my pipeline,  
So that I can immediately debug, log, or visualize what's happening at each step without managing string keys.

**As a third-party shader author,**  
I want to integrate my Metal kernels with minimal Swift wrapper code,  
So that my shaders work seamlessly in the chaining system.

## Functional Requirements

### Core Chaining API

1. **The system must provide a fluent chaining syntax** similar to SwiftUI view modifiers for composing shader operations
2. **The system must separate pipeline setup from execution** - build/compile the chain once, then execute repeatedly with different images for optimal performance
3. **The system must validate shader chain compatibility at compile-time** using Swift protocols and generics
4. **The system must support texture-only payloads** between shader operations in the chain
5. **The system must allow parameter configuration** via uniform/constant structs (MTLBuffer)
6. **The system must provide strongly-typed tap points** with callback functions (`tapImage { image in }`, `tapPoints { points in }`, `tapData { data in }`) for immediate CPU visibility without mid-chain read-backs

### Performance Requirements

7. **The system must maintain ≥30 fps performance** for typical pipelines on M1 MacBook Air
8. **The system must work with any input resolution** with typical usage ≤2000px, usually ≤600px  
9. **The system should provide an optional chain optimizer** that fuses contiguous operations for ≥10% speed improvements
10. **The system must operate GPU-only** with minimal CPU/energy impact

### Extensibility Requirements

11. **The system must support adding custom shaders** with one `.metal` kernel + `Params` C-struct + Swift descriptor (~40 LOC total)
12. **The system must provide `ConventionBasedShader("blur.metal")`** helper for quick shader loading with default I/O rules
13. **The system must require explicit opt-in for chainability** via `ChainableShader` protocol
14. **The system should support loading external `.metallib` files** (caller responsible for safety)

### Built-in Shader Library

15. **The system must include ~10 common image processing kernels** (blur, grayscale, erosion, debayer, etc.)
16. **The system must provide configuration structs** for all built-in shader parameters
17. **The system must support the canonical benchmark pipeline:** Bayer→RGB, Grayscale, B&W threshold, Erosion, Blob detection

### Developer Experience

18. **The system must provide clear compiler errors** for incompatible shader chain configurations  
19. **The system must include SwiftUI preview components** for development and debugging (ideal, not required for v1.0)
20. **The system must work through Swift Package Manager** distribution only

## Non-Goals (Out of Scope)

- **XCFramework binaries** - SPM source distribution only for launch
- **LUT & argument-buffer support** - future work
- **Automatic chainability inference** - explicit opt-in required  
- **Runtime parameter rebinding** without chain rebuild - future work
- **Image-based visual testing** - manual image review only, not diffs
- **Heavy hardware compatibility checking** - rely on SPM min deployment targets
- **Sandboxed shader execution** - full Metal access allowed with compile-time validation

## Design Considerations

### API Design Philosophy
- **Swift-first** fluent syntax that feels natural to SwiftUI developers
- **Functional callbacks over string keys** - tap functions use closures for immediate data access
- **Explicit over implicit** - developers must opt-in to chainability
- **Performance over purity** - willing to trade complexity for speed

### Chaining Syntax Example
```swift
// Setup pipeline once (no image data)
let pipeline = try await metalEngine
    .debayer(.RGGB)
    .tapImage { image in 
        // Debug: save intermediate RGB result
        saveDebugImage(image, name: "raw_rgb")
    }
    .grayscale(.luminance)  
    .blackAndWhite(threshold: 0.5)
    .erosion(kernelSize: 3)
    .tapPoints { detectedBlobs in
        // Process detected blob coordinates
        analyticsTracker.recordBlobCount(detectedBlobs.count)
    }
    .build() // Compile and optimize the chain

// Execute repeatedly with different images
let result1 = try await pipeline.execute(inputImage1)
let result2 = try await pipeline.execute(inputImage2)
let result3 = try await pipeline.execute(inputImage3)
```

### Error Handling Strategy
- **Compile-time**: Protocol mismatches fail to compile
- **Runtime**: GPU memory issues may generate warnings
- **Load-time**: Invalid `.metallib` files throw descriptive errors

## Technical Considerations

### Architecture
- **MetalAlloy** (package) → **Corium** (core GPU) → **Forge** (builder/chaining) → **StarliteDemo** (sample app)
- Built on existing `CommonMetalEngine` foundation
- Maintains current shader library (~10 operations)

### Performance Optimization
- **Two-phase execution:** Pipeline setup/compilation happens once; image processing happens repeatedly for maximum throughput
- Chain optimizer fuses operations up to—but not across—tap boundaries
- Optimizer is mandatory if ≥50% speedup, optional if ≥10% speedup  
- Target: canonical pipeline benchmarks at multiple resolutions

### Dependencies
- Requires Metal-capable hardware
- Swift 5.9+ for advanced generics features
- macOS 12+ / iOS 15+ minimum deployment targets

## Success Metrics

### Performance Metrics
- **≥30 fps sustained performance** on canonical benchmark pipeline (M1 MacBook Air)
- **≥10% performance improvement** when chain optimizer is engaged
- **No performance regression >10%** compared to current individual shader calls

### Developer Experience Metrics  
- **Internal team migration time <1 day** (manual refactor of ~12 call sites)
- **New shader integration time ≤40 LOC** for third-party developers
- **Pipeline creation time <10 minutes** for 5-step chains by experienced Swift developers

### Quality Metrics
- **100% compile-time safety** for shader chain compatibility
- **Zero runtime pipeline configuration errors** in well-formed chains
- **100% Swift test coverage** for wrapper logic and numerical computations

## Open Questions

### Technical Questions
1. **Chain optimizer implementation:** Should fusion happen at Metal shader level or compute command level?
2. **Memory pressure handling:** What specific warnings/fallbacks for GPU memory constraints?
3. **Preview component scope:** How much SwiftUI debugging UI is needed for v1.0 vs future work?

### Product Questions  
4. **External shader validation:** Do we need any safety checks beyond compile-time validation?
5. **Documentation strategy:** In-code `///` comments vs separate markdown files for complex examples?
6. **Community contribution model:** How do we encourage third-party shader contributions?

### Performance Questions
7. **Benchmark hardware matrix:** Should we test beyond M1 MacBook Air and M3 Mac mini?
8. **Resolution scaling behavior:** What's the expected performance curve from 600px to 2000px inputs?

---

**Next Steps:** 
1. Validate this PRD with stakeholders  
2. Begin alpha implementation this weekend (≤4h target)
3. Set up performance benchmarking infrastructure
4. Plan migration strategy for consumer app 