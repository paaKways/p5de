# Engineering Learnings

## 2026-03-14 - UI/DI Boundaries Improve Testability
- Learning: Passing full `AppDependencies` into page widgets caused high coupling and brittle widget tests.
- Decision: Keep dependency containers in app/root composition only; pass narrow callbacks/ports into pages.
- Applied in:
  - `lib/app/app.dart`
  - `lib/contexts/sketch_catalog/presentation/sketch_catalog_page.dart`
- Follow-up: Use the same pattern for editor/runtime pages.

## 2026-03-14 - Web Storage Clear Needed Cache Invalidation
- Learning: Clearing `shared_preferences` alone did not clear in-memory repository cache, so UI looked unchanged.
- Fix: Added storage version invalidation so repository reloads after clear action.
- Applied in:
  - `lib/contexts/sketch_catalog/infrastructure/web_local_storage_sketch_repository.dart`
  - `lib/contexts/sketch_catalog/presentation/sketch_catalog_page.dart`
- Follow-up: Add a small web-specific test for clear action behavior.

## 2026-03-14 - Platform-Specific Repositories Enable Fast Iteration
- Learning: Native Drift code path blocks web compilation when imported directly in common DI wiring.
- Fix: Use conditional imports for repository factories and keep platform-specific implementation separate.
- Applied in:
  - `lib/app/di/app_dependencies.dart`
  - `lib/app/di/sketch_repository_factory_native.dart`
  - `lib/app/di/sketch_repository_factory_web.dart`
- Follow-up: Consider formal environment/profile docs for dev workflows (web-fast vs android-real).
