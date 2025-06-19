//
//  GrayscaleConversion.swift
//  GravityWell
//
//  Created by Bryan Costanza on 6/14/25.
//

public enum GrayscaleConversionStrategy: CaseIterable, Sendable {
    case weighted      // Standard luminance weights: 0.299*R + 0.587*G + 0.114*B
    case average       // Simple average: (R + G + B) / 3
    case redChannel    // Use red channel only
    case greenChannel  // Use green channel only  
    case blueChannel   // Use blue channel only
    case maxChannel    // Use brightest channel
    case minChannel    // Use darkest channel

    public var displayName: String {
        return switch self {
            case .weighted:     "Weighted Luminance"
            case .average:      "Average RGB"
            case .redChannel:   "Red Channel"
            case .greenChannel: "Green Channel"
            case .blueChannel:  "Blue Channel"
            case .maxChannel:   "Brightest Channel"
            case .minChannel:   "Darkest Channel"
        }
    }
}
