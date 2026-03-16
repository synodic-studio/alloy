

> **Elevator pitch**  
> *Chain blazing-fast Metal kernels with Swift-style ergonomics and compile-time guarantees.*

---

## 1 Goals & Success Metrics

| Metric | Target |
|--------|--------|
| **Frame rate** | ≥ 30 fps on M1 MacBook Air (60 fps is “stellar”) |
| **Input size** | Works for any resolution; typical ≤ 2000 px, usually ≤ 600 px |
| **Resource footprint** | GPU‑only; CPU/energy largely irrelevant |
| **Compile‑time safety** | All I/O mismatches fail at compile time via protocols & generics |
| **Extensibility friction** | ≤ 40 LOC to add a third‑party shader (Tier B) |

---

## 2 Current State Snapshot

| Item | Status |
|------|--------|
| **Public shaders** | ≈ 10 kernels, each with its own config struct |
| **Tap helpers** | ≈ 5 ad‑hoc `tap` functions |
| **Top pain points** | 1. Edit multiple files per new shader  <br>2. Metal unfamiliarity breeds errors  <br>3. No guidance/checks when chaining |
| **Deprecation** | Old API deleted once consumer app migrates (minutes–hours) |

---

## 3 Design Principles

* **Swift‑first** – fluent chaining syntax that feels like SwiftUI view modifiers  
* **Compile‑time guarantees** – concrete generics & protocols; no type erasure in hot path  
* **Performance over purity** – willing to double compute cost as long as ≥ 30 fps; provide opt‑in optimizer for ≥ 10 % wins  
* **Explicit power‑user doors** – authors opt‑in with `ChainableShader`; nothing happens “by magic”

---

## 4 Benchmark & Performance Validation

**Canonical pipeline (perf gate):**

1. **Bayer → RGB** (*tap full‑res image*)  
2. Grayscale (strategy‑selectable)  
3. **B&W threshold** (adjustable)  
4. **Erosion**  
5. **Blob detect** (*tap point list*)

**Decision rule:** keep chaining optimizer if it yields ≥ 10 % speed‑up (mandatory if ≥ 50 %). Optimizer fuses contiguous `ChainableShader`s up to—but not across—tap boundaries.

---

## 5 Data Flow Contract (v 1.0)

| Aspect | Decision |
|--------|----------|
| **Inter‑shader payloads** | Textures only |
| **Parameter transport** | Uniform/constant structs (`MTLBuffer`) |
| **CPU visibility** | No mid‑chain read‑backs; only strongly‑typed taps (`tapImage`, `tapPoints`, `tapData`, …) |
| **Future Work** | LUT & argument‑buffer support, histogram/reduction buffers |

---

## 6 Extensibility Model

| Topic | Specification |
|-------|---------------|
| **Minimum plugin effort** | **Tier B** – one `.metal` kernel + `Params` C‑struct + Swift `ShaderNode & ChainableShader` descriptor (≈ 40 LOC) |
| **Easy‑mode helper** | `ConventionBasedShader("blur.metal")` – loads kernel with default I/O rules (not chainable) |
| **Chaining opt‑in** | **Explicit** via `ChainableShader` or `.supportsChaining()` |
| **Guardrails on `.metallib`** | None – loading external code is caller’s responsibility |
| **Future Work** | Signature verification, automatic chainability inference, Tier C full‑custom nodes |

---

## 7 Package, Licensing & Versioning

| Item | Choice |
|------|--------|
| **Distribution** | Swift Package Manager only (launch) |
| **License** | Apache 2.0 |
| **Name hierarchy** | `MetalAlloy` (package) → `Corium` (core GPU) → `Forge` (builder/chaining) → `StarliteDemo` (sample app) |
| **Version scheme** | Calendar versioning – `2025.6.0`, `2025.6.1`, … |

---

## 8 Deprecation & Migration

* Old API lives only until the in‑house app is rebuilt (expected < 1 day).  
* Manual refactor acceptable (≈ 12 call sites).  
* No telemetry required.

---

## 9 Testing & Continuous Integration

| Area | Approach |
|------|----------|
| **Hardware** | Dev: M1 MacBook Air • CI/Prod: M3 Mac mini |
| **Coverage goal** | 100 % of Swift wrapper logic & numerical unit tests |
| **Visual validation** | Separate “snapshot” test target saves representative images for manual review (no image diffs) |
| **Performance tests** | Script runs canonical pipeline at multiple resolutions; CI fails if < 30 fps or regression > 10 % |

---

## 10 Timeline & Resources

| Phase | ETA | Notes |
|-------|-----|-------|
| **Alpha refresh** | This weekend (≤ 4 h) |
| **Public 2025.6.0** | After consumer‑app migration (tens of hours total) |
| **Community preview** | Blog post + `StarliteDemo` once docs stabilize |

---

## 11 Future Work / Backlog

* LUT & argument‑buffer support  
* Automatic fusion of chainable nodes (remove explicit opt‑in)  
* Guarded loading (signature or build‑time only)  
* Pre‑built XCFramework binaries  
* Runtime parameter rebinding without chain rebuild  
* Histogram / reduction helpers  
* SwiftData‑style codegen for parameter structs  