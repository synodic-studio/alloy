import Foundation

// MARK: - Helper Methods

internal func createMockRawData(width: Int, height: Int, bitDepth: Int) -> Data {
    let bytesPerPixel = bitDepth == 16 ? 2 : 1
    let count = width * height * bytesPerPixel
    return Data(repeating: 128, count: count)
}

internal func createMockImageData(width: Int, height: Int) -> Data {
    let bytesPerPixel = 4 // RGBA
    let count = width * height * bytesPerPixel
    return Data(repeating: 255, count: count)
} 