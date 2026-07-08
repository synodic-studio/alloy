//
//  Pipeline.swift
//  Alloy
//
//  A phantom-typed, value-semantic frontend over `CommonMetalEngine`.
//
//  `State` records the semantic kind of image the pipeline currently holds
//  (`ColorImage`, `Binary`, …). Operations are offered only where the state
//  permits (via constrained extensions), so invalid orderings — e.g. eroding
//  before thresholding — fail to compile rather than producing silent garbage
//  at runtime.
//
//  The pipeline is a lightweight recording of stages. `prepared()` builds the
//  configured engine ONCE without executing, for the build-once / execute-many
//  cached pattern (30fps loops). `run(on:)` builds and executes in one shot.
//

import Foundation

public struct Pipeline<State> {
    /// Input width the pipeline was seeded with (metadata).
    public let width: Int
    /// Input height the pipeline was seeded with (metadata).
    public let height: Int

    /// Builds and configures a fresh engine carrying this pipeline's stages,
    /// without executing it.
    let build: () throws -> CommonMetalEngine

    init(width: Int, height: Int, build: @escaping () throws -> CommonMetalEngine) {
        self.width = width
        self.height = height
        self.build = build
    }

    /// Appends a stage that advances the pipeline to `NewState`.
    func appending<NewState>(
        _ stage: @escaping (CommonMetalEngine) throws -> CommonMetalEngine,
    ) -> Pipeline<NewState> {
        let base = build
        return Pipeline<NewState>(width: width, height: height) { try stage(base()) }
    }

    /// Builds and configures the engine for this pipeline's stages, internal helper.
    func makeConfiguredEngine() throws -> CommonMetalEngine {
        try build()
    }

    /// Builds the configured engine **once, without executing it**, and returns
    /// it for reuse. This is the build-once / execute-many entry point: cache the
    /// returned engine and call `execute(data:)` on it per frame. The phantom
    /// type has already proved the stage ordering at construction; per-frame
    /// execution is exactly the untyped engine's, unchanged.
    public func prepared() throws -> CommonMetalEngine {
        try build()
    }

    /// Builds and executes the pipeline against a frame of input data in one shot.
    public func run(on data: Data) throws -> BaseShaderResult {
        try prepared().execute(data: data)
    }
}

public extension Pipeline where State == ColorImage {
    /// Entry point: a pipeline seeded with already-debayered RGBA data.
    static func rgba(width: Int, height: Int) -> Pipeline<ColorImage> {
        Pipeline<ColorImage>(width: width, height: height) {
            guard let engine = CommonMetalEngine() else {
                throw MetalEngineError.generalError(message: "Failed to create Metal engine")
            }
            return try engine.withRGBAData(width: width, height: height)
        }
    }

    /// Adopt an existing engine already configured to a full-frame colour state
    /// (e.g. GravityWell's `makeFullFrameColorBaseEngine()`), so its downstream
    /// stages gain compile-time ordering safety.
    ///
    /// - Important: this is an **unchecked** assertion that `engine` is at the
    ///   `ColorImage` state — the caller vouches for it. Alloy cannot verify the
    ///   state of an engine built outside the `Pipeline` API.
    static func colorBase(_ engine: CommonMetalEngine, width: Int, height: Int) -> Pipeline<ColorImage> {
        Pipeline<ColorImage>(width: width, height: height) { engine }
    }
}
