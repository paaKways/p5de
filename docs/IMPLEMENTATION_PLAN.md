# Implementation Plan
## Product: Mobile Processing Java and p5.js Editor & Runtime App
## Date: March 12, 2026
## Inputs
- PRD: `PRD.md`
- TDD: `TDD.md`
- ADRs: `docs/adr/ADR-001..005`

## 1. Objective
Deliver the MVP defined in the PRD using the Flutter + DDD + BLoC architecture defined in the TDD, with a working offline create/edit/delete/run experience for Processing Java and p5.js sketches on Android mobile devices.

## 2. Delivery Strategy
Use vertical slices that each ship end-to-end value:
1. Foundation + Architecture
2. Sketch Catalog (CRUD)
3. Editor (CodeMirror + autosave)
4. Runtime Preview (Processing Java WASM + p5.js run/stop/restart + error console)
5. Hardening (performance, reliability, QA, telemetry)

## 3. Milestones and Scope
### Milestone 0: Project Foundation (Week 1)
Scope:
- Initialize Flutter project and Android target configuration.
- Set up DDD folder structure and dependency injection baseline.
- Add core packages: `flutter_bloc`, `equatable`, `drift`, `sqlite3_flutter_libs`, `path_provider`, `flutter_inappwebview`, Firebase SDKs.
- Configure CI pipeline (`flutter analyze`, tests, format checks).
- Create architecture docs placeholder (`docs/architecture/mvp-components.md`).

Definition of done:
- App builds and runs on target Android emulator/device.
- CI passes on default branch.
- Folder/module boundaries reflect TDD bounded contexts.

### Milestone 1: Sketch Catalog (Weeks 2-3)
Scope:
- Implement `Sketch` aggregate, repository contracts, Drift schema.
- Implement use cases: `CreateSketch`, `RenameSketch`, `DeleteSketch`, `SearchSketches`, `ListSketches`.
- Implement `SketchCatalogBloc` and catalog UI.
- Add validation and duplicate-name handling.

Definition of done:
- User can create/list/search/rename/delete sketches locally.
- Data persists across app relaunch.
- Unit + bloc tests pass for catalog domain/application/presentation.

### Milestone 2: Editor Slice (Weeks 4-5)
Scope:
- Integrate CodeMirror 6 inside InAppWebView.
- Implement editor bridge adapter and draft model.
- Implement `EditorBloc` and use cases: `LoadSketchForEdit`, `UpdateDraft`, `SaveSketch`.
- Add sketch language/runtime selection metadata so drafts can target Processing Java (`Sketch.pde`) or p5.js (`sketch.js`).
- Implement autosave (debounced and lifecycle-triggered).
- Add save/dirty-state indicators.

Definition of done:
- User can open a Processing Java or p5.js sketch and edit code with syntax highlighting.
- Autosave works reliably on typing pause and app background.
- Editor tests cover state transitions and save behavior.

### Milestone 3: Runtime Preview Slice (Weeks 6-7)
Scope:
- Add runtime HTML shell + bundled p5.js assets.
- Add bundled WASM Processing Java runtime assets and runtime loader shell.
- Implement runtime adapter, JS bridge handlers, and console/error mapping.
- Implement `RuntimeBloc` and use cases: `RunSketch`, `StopSketch`, `RestartSketch`, with runtime dispatch based on sketch language.
- Add runtime watchdog and unresponsive recovery UX.
- Map Processing Java compile/runtime diagnostics back to `Sketch.pde` lines where available.

Definition of done:
- User can run/stop/restart Processing Java and p5.js sketches from editor flow.
- Errors appear in console with best-effort line mapping.
- Runtime works offline and survives basic orientation changes.

### Milestone 4: Hardening and Beta Readiness (Week 8)
Scope:
- Performance tuning against TDD budgets.
- Orientation, background/foreground, and process-death recovery QA.
- Add telemetry events and Crashlytics tagging.
- Polish UX and fix P0/P1 defects.

Definition of done:
- PRD acceptance criteria pass on device matrix.
- Crash-free session target trend >=99.5% in beta window.
- Release candidate is signed and distributable to testers.

## 4. Work Breakdown by Bounded Context
### `sketch_catalog`
- Domain:
  - `Sketch` aggregate and name value object.
- Application:
  - CRUD/search/list use cases.
- Infrastructure:
  - Drift DAO + repository implementation.
- Presentation:
  - `SketchCatalogBloc`, list and actions UI.

### `editor`
- Domain:
  - Draft rules, save policy, and sketch language/runtime metadata.
- Application:
  - load/update/save use cases.
- Infrastructure:
  - CodeMirror bridge adapter, language mode configuration, and draft persistence adapter.
- Presentation:
  - `EditorBloc`, editor screen, status indicators.

### `runtime_preview`
- Domain:
  - runtime session model, runtime target selection, watchdog policy, runtime error model.
- Application:
  - run/stop/restart use cases.
- Infrastructure:
  - p5.js WebView adapter, Processing Java WASM runtime adapter, injected JS/error hooks.
- Presentation:
  - `RuntimeBloc`, preview/console UI.

## 5. Dependency and Critical Path
Critical path:
1. Drift schema + repository contracts
2. Catalog use cases + bloc
3. Editor integration + autosave
4. Runtime integration + run lifecycle
5. Hardening and QA

Key dependencies:
- Runtime depends on editor snapshot contract.
- Processing Java runtime depends on stable WASM asset packaging and a bridge contract for compile/runtime diagnostics.
- Editor and catalog both depend on repository stability.
- Telemetry and crash tagging depend on stable event/state model in blocs.

## 6. Quality Gates
Gate A (post Milestone 1):
- CRUD reliability tests passing
- Persistence validated across relaunch

Gate B (post Milestone 2):
- Editor typing responsiveness within target on mid-range device
- Autosave reliability under lifecycle transitions

Gate C (post Milestone 3):
- Run-to-first-frame median <= 1.5s for simple p5.js sketches and an explicitly measured target for simple Processing Java WASM sketches
- No crash on run/stop/restart/orientation baseline scenarios
- Processing Java compile/runtime errors appear in the console with best-effort line mapping

Gate D (release):
- All PRD acceptance criteria pass
- No open P0 defects; P1 defects triaged with explicit disposition

## 7. Testing Plan
- Unit tests:
  - Domain entities/value objects and use cases.
- BLoC tests:
  - event/state transitions for catalog, editor, runtime blocs.
- Integration tests:
  - full flow: create -> edit -> save -> run -> stop -> delete for both Processing Java and p5.js sketch types.
- Device tests:
  - orientation changes, background/foreground, process restart.

## 8. Risks and Mitigations
- WebView variance across devices:
  - Maintain API/device test matrix and fallback runtime settings.
- Editor performance degradation:
  - Keep extension set minimal; benchmark before merging large editor changes.
- Runtime hangs from user scripts:
  - Watchdog + force restart + clear user messaging.
- Processing Java WASM runtime startup/size risk:
  - Bundle assets locally, track APK size impact, benchmark cold/warm start, and keep diagnostics mapping best-effort for MVP.
- Architecture erosion:
  - Enforce dependency rules in code review (no infra imports in domain/application).

## 9. Ownership Model
- Product/Design:
  - acceptance criteria clarity, UX signoff.
- Mobile Engineering:
  - architecture, implementation, testing.
- QA:
  - device matrix validation, regression suites.
- DevOps/Release:
  - CI stability and beta distribution pipeline.

## 10. Execution Tracking
Track weekly in a simple board with columns:
- `Backlog`
- `In Progress`
- `In Review`
- `Blocked`
- `Done`

Each task should include:
- bounded context
- layer (`presentation/application/domain/infrastructure`)
- acceptance checks
- linked ADR/TDD section when architecture-impacting

## 11. Immediate Next Actions
1. Start Milestone 2 editor slice:
   - Add sketch language/runtime metadata to catalog creation.
   - Implement CodeMirror 6 inside `InAppWebView`.
   - Add `EditorBloc`, draft autosave, dirty-state tracking, and bridge tests.
2. Prepare Milestone 3 runtime foundations:
   - Define p5.js runtime shell asset contract.
   - Define Processing Java WASM runtime asset layout and Dart-JS bridge contract.
   - Add first-run performance and diagnostics mapping checkpoints for the WASM runtime.
3. Keep Milestone 1 catalog regression checks green while editor navigation is introduced.
