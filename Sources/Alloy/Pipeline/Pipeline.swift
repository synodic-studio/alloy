//
//  Pipeline.swift
//  Alloy
//
//  A phantom-typed, value-semantic frontend over `CommonMetalEngine`.
//
//  `State` records the semantic kind of image the pipeline currently holds
//  (`Color`, `Binary`, …). Operations are offered only where the state
//  permits (via constrained extensions), so invalid orderings — e.g. eroding
//  before thresholding — fail to compile rather than producing silent garbage
//  at runtime.
//
//  The pipeline is a lightweight recording of stages; execution is deferred to
//  `run(on:)`, which replays the recording onto a fresh engine. This keeps the
//  existing build-once / execute-per-frame engine internals intact.
//

import Foundation

public struct Pipeline<State> {
    /// Input width the pipeline was seeded with.
    public let width: Int
    /// Input height the pipeline was seeded with.
    public let height: Int

    /// Replays the recorded stages onto a freshly configured engine.
    let build: (CommonMetalEngine) throws -> CommonMetalEngine

    init(
        width: Int,
        height: Int,
        build: @escaping (CommonMetalEngine) throws -> CommonMetalEngine,
    ) {
        self.width = width
        self.height = height
        self.build = build
    }

    /// Appends a stage that advances the pipeline to `NewState`.
    func appending<NewState>(
        _ stage: @escaping (CommonMetalEngine) throws -> CommonMetalEngine,
    ) -> Pipeline<NewState> {
        Pipeline<NewState>(width: width, height: height) { engine in
            try stage(build(engine))
        }
    }

    /// Builds and configures a fresh engine carrying this pipeline's stages.
    func makeConfiguredEngine() throws -> CommonMetalEngine {
        guard let engine = CommonMetalEngine() else {
            throw MetalEngineError.generalError(message: "Failed to create Metal engine")
        }
        return try build(engine)
    }

    /// Executes the pipeline against a frame of RGBA input data.
    public func run(on data: Data) throws -> BaseShaderResult {
        try makeConfiguredEngine().execute(data: data)
    }
}

public extension Pipeline where State == ColorImage {
    /// Entry point: a pipeline seeded with already-debayered RGBA data.
    static func rgba(width: Int, height: Int) -> Pipeline<ColorImage> {
        Pipeline<ColorImage>(width: width, height: height) { engine in
            try engine.withRGBAData(width: width, height: height)
        }
    }
}
