# Changelog

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
