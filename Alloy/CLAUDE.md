# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Alloy is a Swift Metal framework for GPU-accelerated image processing operations. It provides a unified engine using a builder pattern to chain shader operations for computer vision and image processing tasks.

## Key Architecture

### Core Components

- **CommonMetalEngine**: Main engine class that chains shader operations using a builder pattern
- **MetalEngine**: Base class providing Metal device management and shader compilation
- **ShaderOperation**: Protocol-based operations that can be chained together
- **Extensions**: Individual shader operations (blur, debayer, erosion, etc.) as extensions to CommonMetalEngine

### Data Flow

1. Configure engine with `withRawData()` or `withRGBAData()`
2. Chain operations using builder pattern (e.g., `.debayer().grayscale().blur()`)
3. Execute with `execute()` method
4. Results returned as `MetalShaderResult` with texture and data access

### Shader Architecture

- Metal shaders in `/Sources/Alloy/Shaders/` directory
- Each shader operation has corresponding Swift extension, parameter model, and Metal file
- Shaders are compiled at runtime and cached in pipeline states

## Development Commands

### Building
```bash
# Build the Swift package
swift build

# Build in Xcode
open Alloy/.swiftpm/xcode/package.xcworkspace
```

### Testing
```bash
# Run all tests
swift test

# Run specific test
swift test --filter <TestName>

# Run tests in Xcode
# Use Test Navigator in Xcode workspace
```

### Development
```bash
# Generate Xcode project
swift package generate-xcodeproj

# Open in Xcode
open Alloy/.swiftpm/xcode/package.xcworkspace
```

## Code Organization

### Parameter Models (`/Models/`)
Each shader operation has a corresponding parameter struct conforming to `MetalShaderParameters`

### Shader Extensions (`/Extensions/`)
- `CommonMetalEngine+[Operation].swift` - Swift implementation
- Individual operations like blur, debayer, erosion, etc.

### Metal Shaders (`/Shaders/`)
- `.metal` files containing GPU compute kernels
- Function mapping handled in `MetalEngine.functionToFileMapping`

### Views (`/Views/`)
- SwiftUI preview components for individual operations
- `FullPipelinePreview` demonstrates complete processing pipeline

## Testing Structure

- **Unit Tests**: Individual shader operations in `/Tests/AlloyTests/Shaders/`
- **Integration Tests**: End-to-end pipeline testing
- **Performance Tests**: GPU performance benchmarking
- **Test Helpers**: Mock data generation utilities

## Platform Requirements

- macOS 14.0+
- Metal-capable GPU
- Swift 5.9+
- No external dependencies (uses system Metal/MetalKit)

## Common Patterns

### Adding New Shader Operations

1. Create parameter model in `/Models/`
2. Add Metal shader in `/Shaders/`
3. Create Swift extension in `/Extensions/`
4. Update function mapping in `MetalEngine`
5. Add corresponding tests
6. Create preview view if needed

### Error Handling

Use `MetalEngineError` for Metal-specific errors. All operations can throw, particularly during shader compilation and execution phases.