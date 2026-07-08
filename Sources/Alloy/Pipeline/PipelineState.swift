//
//  PipelineState.swift
//  Alloy
//
//  Phantom marker types describing the semantic state of the image flowing
//  through a `Pipeline`. These types are uninhabited — they exist only in the
//  type system, so that stage constraints are checked at compile time and
//  invalid orderings simply fail to compile.
//

/// The root capability: a value that represents some image state.
public protocol ImageState {}

/// Capability protocol marking image states that are known to be binary
/// (white blobs on black), and therefore safe to erode / analyse for
/// connected components. This is the `BlackAndWhite` idea sketched in
/// `ProtocolPlayground.swift`, carried by a phantom type rather than an
/// eagerly-executed texture value.
public protocol BlackAndWhite: ImageState {}

/// Full-colour (RGBA) image state — the input to thresholding.
///
/// Named `ColorImage` rather than `Color` deliberately: a module-scoped
/// `Color` shadows `SwiftUI.Color` for any file importing both, which is
/// exactly the SwiftUI-ergonomics trap this frontend exists to avoid. Users
/// rarely spell the state anyway — the `.rgba(...)` entry point infers it.
public enum ColorImage: ImageState {}

/// Binary (black-and-white) image state — the output of `blackAndWhite`, and
/// the only state on which erosion / connected components are offered.
public enum Binary: BlackAndWhite {}
