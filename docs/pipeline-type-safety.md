# Pipeline Type Safety — Design Direction

**Goal:** invalid stage orderings should fail to compile, not misbehave at runtime, while keeping the builder natural for a SwiftUI developer and keeping the extension-per-operation workflow cheap. Scope is the existing operation set only.

---

## 1. The essential model, and where it leaks

One holdable statement: **`CommonMetalEngine` is a mutable class that accumulates `[ShaderOperation]` via chaining extensions, allocates each stage's output texture eagerly at chain-build time (with a 1×1 placeholder input), and at `execute(data:)` uploads the `Data`, then re-threads textures through the array — re-discovering each operation's parameter type with an 11-way `as?` downcast chain** (`Sources/Alloy/CommonMetalEngine.swift:127–274`).

The generic in `TypedShaderOperation<P>` (`Sources/Alloy/ShaderOperations/TypedShaderOperation.swift`) types the *parameter struct*, never the *image state*. It is erased into `[ShaderOperation]` immediately, and the image-kind flowing between stages (raw Bayer, color, grayscale, binary) exists nowhere in the type system — only implicitly in the order the caller happened to write. Every intermediate texture is `rgba8Uint` regardless of meaning (see the identical descriptors in every `Extensions/CommonMetalEngine+*.swift`), so even Metal's pixel-format validation can't catch semantic misordering; the only *format* boundary is raw `r8Uint/r16Uint` vs `rgba8Uint`, i.e. exactly the debayer transition.

What compiles today but is wrong, by failure mode:

- **Compiles, silent garbage at runtime** (the worst class):
  - `.withRGBAData(...).debayerRGGB(...)` — the debayer kernel treats color pixels as Bayer sensels. Nothing throws; output is nonsense (inference from kernel input expectations; not observed live).
  - `.withRawData(...).grayscale(...)` skipping debayer — grayscale samples RGBA semantics from a single-channel texture.
  - `.erosion(...)` or `.connectedComponents(...)` on a non-binary image — both extensions *document* the binary requirement in comments (`+ConnectedComponents.swift:5–6`) but accept anything. Morphology on grayscale produces plausible-looking wrong output, the exact bug class that burns exhibit-debugging time.
  - `.blur(...)` or `.noise(...)` *after* thresholding then `.connectedComponents(...)` — blurring destroys binariness; the type system today has no idea.
  - `executeConnectedComponentsWithTexture(inputTexture:)` (`+ConnectedComponents.swift:75`) accepts any `MTLTexture` — this is GravityWell's actual per-frame entry point (`gravity-well/GravityWell/Managers/DetectionManager+BallDetection.swift:70–76`), and the binary contract crosses an engine boundary carried by nothing but a comment.
- **Compiles, throws at chain-build time:** any op before `withRawData`/`withRGBAData` (the `inputWidth > 0` guards); `.donutMask` on non-square input (`+DonutMask.swift:25`). Runtime `throws` doing a compile-time job.
- **Compiles, throws at `execute()`:** a new operation whose param type isn't added to the downcast chain hits `"Unsupported operation type"` (`CommonMetalEngine.swift:273`). This is a hidden *seventh* step missing from CLAUDE.md's "Adding New Shader Operations" workflow, and it fails only at runtime.

Two smaller structural leaks worth fixing in the same move: dimension bookkeeping is duplicated between `addOperation` (`CommonMetalEngine.swift:328–344`) and `execute` (`:278–293`), each special-casing Debayer/Crop/HSVPosition by downcast; and `ShaderOperation.setParameters(encoder:)` is a defined protocol witness that is never called — the seam for eliminating the downcast chain already exists, unused.

## 2. Options for compile-time stage safety

The state vocabulary is small and closed over the existing ops. Deriving it from the extensions:

| State | Produced by | Consumed by |
|---|---|---|
| `RawBayer` | `withRawData` | `debayerRGGB` (only consumer of r-format) |
| `Color` | `debayerRGGB`, `withRGBAData` | `grayscale`, `hsvPosition`, color sampling; crop/mask/blur/noise/invert preserve it |
| `Grayscale` | `grayscale(strategy:)`, blur/noise applied to `Binary` | `peakDetection`, further blur |
| `Binary` | `blackAndWhite(threshold:)` (and grayscale with equal thresholds, per `+Grayscale.swift:82–95`) | `erosion`, `connectedComponents` |

Crop, donut mask, and invert are state-*preserving*; blur and noise *demote* `Binary` to `Grayscale`. Grayscale-with-equal-thresholds producing binary is value-dependent and can't be typed — the typed surface must route binariness exclusively through `.blackAndWhite(threshold:)`, which already exists and delegates to the identical shader, so nothing is lost.

### Option A — phantom-typed pipeline state

`Pipeline<State>` (a struct), where `State` is one of four uninhabited marker types. Each operation lives in a constrained extension and returns the successor state:

```swift
public enum Binary: BlackAndWhite {}   // uninhabited markers
public enum Color: ImageState {}

extension Pipeline where State: BlackAndWhite {
    public func erosion(iterations: Int = 1, connectivity: ErosionConnectivity = .eight)
        -> Pipeline<State> { ... }
}

extension Pipeline where State == Color {
    public func blackAndWhite(threshold: Double) -> Pipeline<Binary> { ... }
}

extension Pipeline where State: ImageState {          // state-preserving ops
    public func squareCrop(center: (x: Int, y: Int), sideLength: Int) -> Pipeline<State> { ... }
}
```

`.erode()` before thresholding is then a *member-not-found* error — the compiler's honest, familiar message ("value of type `Pipeline<Color>` has no member `erosion`"), which is the best diagnostic Swift can give for this class of constraint.

- **Ergonomics:** identical chaining feel to today; autocomplete becomes *better* — only valid next stages appear.
- **Extension workflow:** composes perfectly. One new file per op, exactly as now, just declaring which state extension it lives in and which state it returns. The state annotation replaces the runtime `guard`s, net less code per op.
- **Compiler/build cost:** negligible — one generic parameter, four marker types, a dozen constrained extensions. No overload-resolution blowups at this scale.
- **Metal constraints:** none. States are semantic; every intermediate stays `rgba8Uint`, threadgroup sizing (`MetalEngine.swift:259–267`) is untouched.
- **Migration:** additive. `Pipeline` is a typed frontend that builds the same `[ShaderOperation]` and hands execution to the existing engine internals. GravityWell at v0.1.5 compiles unchanged.

### Option B — protocol-witnessed capabilities (the ProtocolPlayground direction)

`Sources/ProtocolPlayground.swift` sketches `Erodable` gated by `BlackAndWhite` — capabilities attached to *what the image is*. As written the sketch isn't expressible (a protocol can't gain conformance to another protocol via extension), but its intent maps exactly onto constrained extensions: `erode` exists *only where* the value is known black-and-white. Taken literally — each op returns an eagerly-executed typed texture value (`BinaryTexture`, `ColorTexture`) — it has two real costs: it abandons the deferred build-once/execute-per-frame model that GravityWell's five cached engines depend on (`gravity-well/GravityWell/Services/MetalEngineService+Creation.swift`), forcing texture allocation back into the 30 fps path; and it multiplies wrapper types where a phantom parameter would do.

**Honest synthesis: B is not an alternative to A — it is A's constraint vocabulary.** `BlackAndWhite` becomes the protocol that the `Binary` marker conforms to; `erosion` is declared `where State: BlackAndWhite`. The playground sketch survives intact as the *shape of the constraints*, carried by a phantom-typed deferred builder instead of eager texture values. If a future state should also be erodable (e.g. a mask), it conforms to `BlackAndWhite` and gains `erosion` for free — that extensibility is the part of the owner's sketch worth keeping verbatim.

### Option C — `@resultBuilder` DSL

`buildPartialBlock(accumulated:next:)` (Swift 5.7+) can genuinely thread a changing state type through sequential components, so `Pipeline { Debayer(); Grayscale(.luminance) }` is *technically* achievable with compile-time ordering checks. Rejected on three grounds: diagnostics inside result builders are notoriously opaque ("no exact matches in call to static method `buildPartialBlock`" — the *opposite* of the goal); every operation must become a struct with an initializer, the heaviest possible break from the extension-per-operation workflow; and type-checking cost grows with overload count in exactly the way constrained extensions don't. A result builder is the right tool when the *structure* is tree-shaped (SwiftUI views); this pipeline is a straight line, and method chaining already expresses lines perfectly.

## 3. The SwiftUI-natural surface

What a SwiftUI developer should touch is a **pipeline as a plain value**, not an engine as a mutable class:

```swift
let detection = try Pipeline
    .rawBayer(width: w, height: h, bitDepth: 16)
    .debayerRGGB()
    .squareCrop(center: center, sideLength: side)
    .donutMask(innerRadius: r)
    .blackAndWhite(threshold: threshold)
    .erosion(iterations: n)

let result = try await detection.run(on: frameData)   // BinaryResult
let blobs  = try await detection.connectedComponents(maxComponents: 20).run(on: frameData)
```

Design points, grounded in how GravityWell actually consumes this:

- **Value semantics + `Equatable`.** GravityWell hand-rolls engine-identity caching (`DetectionManager+EngineManagement.swift:35` compares `lastEngineConfig`) and `FullPipelinePreview` re-runs on fourteen separate `.onChange` modifiers (`Views/FullPipelinePreview.swift:47–59`). An `Equatable` pipeline value collapses both into the idiomatic `task(id: pipeline) { result = try await pipeline.run(on: data) }` — SwiftUI's own change-tracking becomes the rebuild logic. The expensive shared Metal state (device, library — already cached process-wide per `Engine/MetalEngine.swift:17`) stays behind the value; texture allocation happens at `run`, or is memoized per pipeline identity.
- **Typed terminal results.** `run` on `Pipeline<Binary>` returns a `BinaryResult`; `.connectedComponents()` is only *offered* on `Pipeline<Binary>` and returns centroids. Critically, `BinaryResult` carries its state as a typed wrapper around the texture, so GravityWell's cross-engine handoff — erosion output texture into a separate connected-components engine — becomes `connectedComponents(input: BinaryResult)` and the binary contract finally crosses the engine boundary *in the type* instead of in a comment. That closes the one hole a single-chain phantom type can't see.
- **Errors:** configuration errors (bad threshold range, non-square donut input where squareness isn't statically known) stay `throws` at chain-build; execution errors surface from `async throws run` and land in the `.task`'s `catch` — the two-phase split a SwiftUI developer already expects from any async resource. No delegates, no completion handlers.
- **Rendering:** results keep `MetalShaderResult`'s `nsImage` path. The commented-out `MetalView.swift` (texture-to-drawable) is the eventual right display surface for the 30 fps path — note it, don't scope it; it's orthogonal to typing.

## 4. Verdict

**Commit to Option A carrying Option B's vocabulary: a phantom-typed `Pipeline<State>` value whose stage constraints are the ProtocolPlayground capability protocols (`BlackAndWhite`/`Erodable` et al.), built as a typed frontend over the existing engine internals.** Method chaining stays (natural for the audience, best diagnostics), states are the four derived above, and the old `CommonMetalEngine` API remains untouched through the transition.

Ride-along fixes the frontend makes nearly free, both already latent in the code:
1. Replace the 11-way downcast chain by finally using the `ShaderOperation` witness — give it `encode(on: MetalEngine) throws` (subsuming the never-called `setParameters`) so adding an op is genuinely one extension file, and the hidden `execute()` edit disappears along with its runtime failure mode.
2. Move the duplicated dimension special-cases into a `transform(size:) -> Size` requirement on the operation.

**Migration path (GravityWell stays green throughout):**
- **v0.2.0:** add `Pipeline<State>` alongside `CommonMetalEngine`, sharing the operation structs and execution path. GravityWell at v0.1.5 is untouched; when it bumps, nothing deprecates yet.
- GravityWell then migrates engine-by-engine — the five builders in `MetalEngineService+Creation.swift` are each a five-line chain, and the only semantic edit is `grayscale(black: t, white: t)` → `.blackAndWhite(threshold: t)` on the preprocessing/threshold engines (identical shader, per `+Grayscale.swift:82`), which is what unlocks `Pipeline<Binary>` and the typed handoff into connected components.
- **v0.3.x:** deprecate the untyped chain methods; remove when GravityWell no longer references them.

**The de-risking spike (small, additive, no GravityWell impact):** implement `Pipeline` for exactly three stages — `.blackAndWhite` (`Color → Binary`), `.erosion` (`where State: BlackAndWhite`), `.connectedComponents` (terminal on `Binary`) — with `Pipeline.rgba(width:height:)` as the entry point, delegating execution to the existing engine. It must demonstrate:
1. `Pipeline.rgba(...).erosion(...)` **does not compile** (member not found), and the diagnostic reads acceptably. SPM can't assert compile failures in tests; keep a `Tests/CompileFixtures/` directory excluded from the target and a script that runs `swiftc -typecheck` expecting nonzero — cheap, honest, good enough for a framework this size.
2. The happy path produces byte-identical output to the same chain through `CommonMetalEngine` (existing `IntegrationTests` patterns cover this).
3. Adding the third op required one new file and no engine edits.

If those three hold on three stages, the remaining nine operations are mechanical transcription of the state table in §2.

---

*Claims marked as inference: exact garbage-output behavior of misordered kernels (debayer-on-RGBA, grayscale-on-raw) is deduced from texture formats and kernel input expectations, not observed live. Everything else cites its file.*
