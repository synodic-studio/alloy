// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Alloy",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "Alloy",
            targets: ["Alloy"]
        ),
    ],
    dependencies: [
        // No external dependencies needed - using system Metal/MetalKit
    ],
    targets: [
        .target(
            name: "Alloy",
            dependencies: [],
            resources: [
                .copy("Shaders"),
            ]
        ),
        .testTarget(
            name: "AlloyTests",
            dependencies: ["Alloy"]
        ),
    ]
)
