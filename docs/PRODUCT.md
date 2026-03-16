# Alloy — Product Overview

## What It Is

Swift Metal framework for GPU-accelerated image processing. Builder-pattern API to chain compute shader operations for real-time computer vision tasks: debayer, blur, erosion, color detection, peak finding.

**Role:** Infrastructure library — powers GravityWell's real-time ball tracking pipeline.

## Tech Stack

- **Swift 5.9+** — macOS 14.0+
- **Metal** — GPU compute shaders
- **MetalKit** — Metal integration
- **Swift Package Manager** — distribution
- **Swift Testing** — test framework
- Zero external dependencies (system frameworks only)

## Current State

**Status: Active development.** Core operations working, test coverage expanding.

- Last commit: 2025-10-19
- 68 source files, ~8,225 LOC
- Unit, integration, and performance test suites
- Recent: GPU color sampling tests

## Architecture

### Builder Pattern
```swift
engine
    .debayer(params)
    .blur(params)
    .erosion(params)
    .peakDetection(params)
    .execute()
```

### Core
- `CommonMetalEngine` — builder pattern entry point
- `ShaderOperation` protocol — operation interface
- Per-operation parameter structs conforming to `MetalShaderParameters`
- Runtime shader compilation with caching

### Operations
- **Debayer** — raw sensor data to RGB
- **Blur** — Gaussian blur
- **Erosion** — morphological erosion
- **Color Inversion** — negate
- **HSV Position Detection** — color-based object finding
- **Peak Detection** — local maxima identification

## Connections

- **gravity-well** — primary consumer (ball tracking pipeline)
- No other external consumers currently
