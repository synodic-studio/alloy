import Testing
import SwiftUI
import AppKit

@testable import Alloy

@Test("Circle Detection Preview Image Generation")
func testCircleDetectionPreviewImageGeneration() throws {
    let imageSize = NSSize(width: 256, height: 256)
    let image = CircleDetectionPreview.generateTestImageWithCircles(size: imageSize)
    
    #expect(image.size.width == imageSize.width)
    #expect(image.size.height == imageSize.height)
    #expect(image.isValid)
}

@Test("Circle Detection Preview View Creation")
func testCircleDetectionPreviewViewCreation() throws {
    // Test that the view can be created without crashing
    let preview = CircleDetectionPreview()
    
    // Basic check that the view exists and has content (this verifies compilation)
    _ = preview.body
    
    // If we get here without crashing, the test passes
    #expect(Bool(true))
} 