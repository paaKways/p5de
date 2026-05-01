# Changelog

## 2026-03-14
### Milestone 2 - Editor Slice Progress Update
- Upgraded ssets/editor/codemirror_host.html to initialize a CodeMirror 6 editor in the native webview host.
- Preserved stable window.editorBridge API (setCode, getCode, ocus) for Flutter integration.
- Added resilient fallback to textarea editor if CodeMirror modules fail to load.
- Added milestone acceptance checklist at docs/progress/M2_ACCEPTANCE_CHECKLIST.md.
### Architecture Docs Update
- Added ADR-006 to capture UI/page boundary decision:
  - keep page widgets decoupled from full `AppDependencies`
  - use narrow callbacks/ports for navigation/composition boundaries
- Added engineering learnings log at `docs/engineering/LEARNINGS.md`.
## 2026-03-13
### Milestone 1 - Persistence Integration (Validated)
- Made `SketchCatalogDatabase` testable by allowing optional `QueryExecutor` injection.
- Added integration test for Drift-backed repository persistence across DB reopen:
  - create + rename in first session
  - reopen same sqlite file
  - list/search verification in second session
  - delete verification after reopen
- Confirmed local validation passed for:
  - `flutter analyze`
  - `flutter test`

### Milestone 1 - Sketch Catalog Presentation (Validated)
- Added `SketchCatalogBloc` events/state handlers for load/create/rename/delete/search flows.
- Added minimal `SketchCatalogPage` wired to bloc.
- Added catalog UI polish:
  - stable widget keys for UI tests
  - delete confirmation dialog
  - readable local timestamp formatting
- Expanded presentation test coverage:
  - bloc tests for rename/delete/search/not-found behavior
  - widget shell assertions for catalog layout and controls
- Confirmed local validation passed for:
  - `dart run build_runner build --delete-conflicting-outputs`
  - `flutter analyze`
  - `flutter test`

## 2026-03-12
### Milestone 0 - Project Foundation
- Bootstrapped Flutter app baseline for Android target.
- Replaced template counter app with app bootstrap and DI entrypoint skeleton.
- Added DDD bounded-context folder structure:
  - `sketch_catalog`
  - `editor`
  - `runtime_preview`
  - `shared`
- Added core dependencies for architecture and runtime plan:
  - `flutter_bloc`, `equatable`
  - `drift`, `sqlite3_flutter_libs`, `path_provider`
  - `flutter_inappwebview`
  - `firebase_core`, `firebase_analytics`, `firebase_crashlytics`
  - `build_runner`, `drift_dev`
- Added CI workflow to run:
  - dependency install
  - formatting check
  - static analysis
  - tests
- Added architecture placeholder doc at `docs/architecture/mvp-components.md`.
- Updated baseline widget test to validate milestone foundation screen rendering.

### Milestone 1 - Sketch Catalog Foundation (Validated)
- Added `Sketch` domain model and `SketchName` value object with validation/normalization.
- Added `SketchRepository` contract with duplicate-name and query operations.
- Added sketch catalog application use cases:
  - `CreateSketch`
  - `RenameSketch`
  - `DeleteSketch`
  - `ListSketches`
  - `SearchSketches`
- Added Drift schema and DAO for local sketch persistence with unique normalized-name index.
- Added Drift-based repository implementation (`DriftSketchRepository`).
- Wired sketch-catalog dependencies and use cases into app DI bootstrap.
- Added initial unit tests for `SketchName` and `CreateSketch`.
- Updated CI to run Drift code generation before format/analyze/test checks.
- Confirmed local validation passed for:
  - `dart run build_runner build --delete-conflicting-outputs`
  - `flutter analyze`
  - `flutter test`


