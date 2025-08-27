//
//  GrayscaleConversion.swift
//  GravityWell
//
//  Created by Bryan Costanza on 6/14/25.
//

public enum GrayscaleConversionStrategy: Int, CaseIterable, Sendable {
    case weighted = 0 // Standard luminance weights: 0.299*R + 0.587*G + 0.114*B
    case average = 1 // Simple average: (R + G + B) / 3
    case redChannel = 2 // Use red channel only
    case greenChannel = 3 // Use green channel only
    case blueChannel = 4 // Use blue channel only
    case maxChannel = 5 // Use brightest channel (RGB)
    case minChannel = 6 // Use darkest channel
    case maxChannelRG = 7 // Use brightest channel (red/green only, ignore blue)

    public var displayName: String {
        switch self {
        case .weighted: "Weighted Luminance"
        case .average: "Average RGB"
        case .redChannel: "Red Channel"
        case .greenChannel: "Green Channel"
        case .blueChannel: "Blue Channel"
        case .maxChannel: "Brightest Channel RGB"
        case .minChannel: "Darkest Channel"
        case .maxChannelRG: "Brightest Channel RG"
        }
    }
}
