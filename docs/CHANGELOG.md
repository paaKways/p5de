# Changelog

## 2026-06-18
### Milestone 4 - June Local Hardening and Content Updates
- Added first-install SuaCode Africa folder/content seeding from `assets/default_projects/suacode_africa`.
- Gated default seeding to first-time users only so existing users, including users who deleted the folder, are not auto-seeded again.
- Added storage probes and a SharedPreferences seed marker for native/web repository bootstrapping.
- Added regression coverage for first-install default content seeding.

### Milestone 4 - Catalog Terminology, UX, and Responsiveness
- Changed user-facing terminology from Project to Folder and Project template to Content.
- Removed the leading icon before "My Sketches" on the main catalog/dashboard.
- Changed sketch list row icons from sparkle/angle-bracket styling to a curly-brace code symbol.
- Optimized the Recent filter path so switching from All to Recent reuses the loaded catalog instead of doing visible press-time reload work.
- Added regression coverage for Recent-filter catalog reuse.

### Build and Device Validation
- Rebuilt and installed a debug APK on Pixel 8 Pro `38041FDJG01HO5`.
- Built a local release APK at `build/app/outputs/flutter-apk/app-release.apk`; artifact size recorded as 59.7 MB.
- Confirmed local validation for the touched areas with:
  - `flutter test test\contexts\sketch_catalog\application\seed_default_projects_test.dart`
  - `flutter test test\widget_test.dart`
  - `flutter test test\contexts\sketch_catalog\presentation\sketch_catalog_bloc_test.dart`
  - `flutter analyze`
  - `flutter build apk --release`
- Release APK build is not yet recorded as signed or distributed release-candidate evidence.

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
