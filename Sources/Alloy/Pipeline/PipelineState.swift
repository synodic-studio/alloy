//
//  PipelineState.swift
//  Alloy
//
//  Phantom marker types describing the semantic state of the image flowing
//  through a `Pipeline`. These types are uninhabited — they exist only in the
//  type system, so that stage constraints are checked at compile time and
//  invalid orderings simply fail to compile.
//
//  State graph (arrows are the transitions the ops in Pipeline/ actually offer):
//
//      RawBayer --debayerRGGB--> ColorImage --grayscale--> Grayscale
//                                    |                          |
//                             blackAndWhite                peakDetection (terminal)
//                                    v
//                                  Binary --erosion--> Binary --connectedComponents--> (terminal)
//
//  squareCrop / donutMask / invert are state-preserving on any DevelopedImage
//  (ColorImage, Grayscale, Binary) — never on RawBayer, whose only valid next
//  step is debayering.
//

/// The root capability: a value that represents some image state.
public protocol ImageState {}

/// A debayered, pixel-addressable image — anything past the raw Bayer stage.
/// Geometric / value ops (crop, mask, invert) are offered here, so they can
/// never be applied to `RawBayer` data (which would corrupt the mosaic).
public protocol DevelopedImage: ImageState {}

/// Capability protocol marking image states that are known to be binary
/// (white blobs on black), and therefore safe to erode / analyse for
/// connected components. This is the `BlackAndWhite` idea sketched in
/// `ProtocolPlayground.swift`, carried by a phantom type rather than an
/// eagerly-executed texture value.
public protocol BlackAndWhite: DevelopedImage {}

/// Raw Bayer sensor data — the only valid next step is `debayerRGGB`.
public enum RawBayer: ImageState {}

/// Full-color (RGBA) image state — the input to grayscale / thresholding.
///
/// Named `ColorImage` rather than `Color` deliberately: a module-scoped
/// `Color` shadows `SwiftUI.Color` for any file importing both, which is
/// exactly the SwiftUI-ergonomics trap this frontend exists to avoid. Users
/// rarely spell the state anyway — the `.rgba(...)` entry point infers it.
public enum ColorImage: DevelopedImage {}

/// Single-channel intensity image — the output of `grayscale(strategy:)`.
public enum Grayscale: DevelopedImage {}

/// Binary (black-and-white) image state — the output of `blackAndWhite`, and
/// the only state on which erosion / connected components are offered.
public enum Binary: BlackAndWhite {}
