# Technical Design Document (TDD)
## Product: Mobile Processing Java and p5.js Editor & Runtime App
## Linked PRD: PRD.md
## Version: 1.1 (MVP Baseline - Flutter)
## Date: March 12, 2026
## Owners: Product + Mobile Engineering

## 1. Purpose
Define how the requirements in the PRD are implemented, including stack choices, architecture, data model, runtime behavior, and operational decisions.

## 2. Scope
In scope:
- Technical implementation for MVP features in PRD
- Architecture and component boundaries
- Tooling, testing, release approach

Out of scope:
- Product goals and prioritization rationale (owned by PRD)

## 3. Requirements Traceability
| PRD Requirement | Technical Approach | Status | Notes |
|---|---|---|---|
| Sketch CRUD | Drift (SQLite)-backed aggregate repository + BLoC-driven Flutter presentation | Baseline selected | Offline-first local storage |
| Editor features | `flutter_inappwebview` hosting CodeMirror 6 with Dart-JS bridge | Baseline selected | Mobile-friendly editing with Processing Java and JavaScript syntax highlighting |
| Runtime run/stop/restart | Separate sandboxed runtime WebView loading either bundled p5.js assets or bundled Processing Java WASM runtime assets | Baseline selected | Hard reset by reload on Stop/Restart |
| Mobile viewport adaptation | Runtime shell uses `resizeCanvas` + `windowResized`; Flutter handles orientation and insets | Baseline selected | Full-screen default, fit mode setting later |
| Offline support | Bundle p5.js and runtime/editor assets in app package; no network dependency | Baseline selected | Full create/edit/run/delete works offline |

## 4. Stack Decisions
### 4.1 Application Framework
- Candidate options:
  - Option A: Native Android (Kotlin)
  - Option B: React Native
  - Option C: Flutter
- Selected option: Option C, Flutter
- Rationale:
  - Fast UI iteration with a single codebase and strong mobile performance.
  - Reliable cross-device rendering and consistent layout behavior.
  - Good ecosystem for WebView, local DB, and state management.
- Tradeoffs accepted:
  - WebView plugin complexity and platform-channel debugging overhead.
  - Additional work to ensure Android WebView behavior is tuned for runtime/editor use.

### 4.2 Runtime Layer
- Candidate options:
  - Embedded WebView + local asset injection for p5.js
  - Embedded WebView + bundled WASM Processing Java runtime for Processing sketches
  - Custom JS engine wrapper
- Selected option: `flutter_inappwebview` + local runtime HTML shells for p5.js and Processing Java WASM
- Security model:
  - JavaScript enabled only in editor/runtime webviews.
  - Dart-JS bridge limited to minimal audited message handlers.
  - Runtime blocks external navigation/resource loads by default in MVP.
  - No broad native APIs exposed to user scripts.
  - Processing Java runs through bundled WASM runtime assets, not a native JVM or arbitrary native execution path.

### 4.3 Editor Component
- Candidate options:
  - Pure Flutter text editor with custom JS highlighting
  - WebView-hosted CodeMirror 6
- Selected option: WebView-hosted CodeMirror 6
- Required capabilities mapping:
  - Syntax highlighting: CodeMirror JavaScript language package and Processing/Java-compatible highlighting mode
  - Undo/redo: CodeMirror history extension
  - Find in file: CodeMirror search extension with Flutter toolbar actions

### 4.4 Data Storage
- Candidate options:
  - SQLite via Drift
  - File-based storage
  - Key-value hybrid
- Selected option: Drift (SQLite) as primary source of truth
- Backup/restore approach:
  - Android Auto Backup enabled by default.
  - Manual import/export deferred post-MVP.

### 4.5 Build, CI/CD, and Release
- Build system: Flutter toolchain + Gradle (Android)
- Core app libraries: `flutter_bloc`, `equatable`, `drift`, `flutter_inappwebview`
- CI provider: GitHub Actions
- Static analysis/linting: `flutter analyze` + `dart format` + `dart_code_metrics`
- Crash/analytics SDK: Firebase Crashlytics + Firebase Analytics

## 5. High-Level Architecture
Architecture style:
- Domain-Driven Design (DDD) with explicit bounded contexts.
- Layers per bounded context: `presentation -> application -> domain -> infrastructure`.
- State management: BLoC/Cubit in the presentation layer only.

Bounded contexts and module boundaries:
- `lib/app`: app bootstrap, dependency injection wiring, navigation composition
- `lib/contexts/sketch_catalog`
  - `presentation`: sketch list/create/rename/delete screens, `SketchCatalogBloc`
  - `application`: use cases (`CreateSketch`, `RenameSketch`, `DeleteSketch`, `SearchSketches`)
  - `domain`: `Sketch` aggregate, value objects, repository contracts, domain services
  - `infrastructure`: Drift tables/DAO adapters, repository implementations
- `lib/contexts/editor`
  - `presentation`: editor UI, autosave indicators, `EditorBloc`
  - `application`: use cases (`LoadSketchForEdit`, `UpdateDraft`, `SaveSketch`)
  - `domain`: editor draft policies, sketch language metadata, and validation rules
  - `infrastructure`: CodeMirror bridge adapter, language mode configuration, and local draft persistence adapter
- `lib/contexts/runtime_preview`
  - `presentation`: runtime preview UI, run state, console panel, `RuntimeBloc`
  - `application`: use cases (`RunSketch`, `StopSketch`, `RestartSketch`)
  - `domain`: runtime session model, runtime target, error model, watchdog policy
  - `infrastructure`: p5.js WebView runtime adapter, Processing Java WASM runtime adapter, JS bridge parser
- `lib/shared`
  - cross-context primitives (result types, clock/uuid ports, logging contracts)

Architecture diagram reference:
- `docs/architecture/mvp-components.md` (to be created with implementation kickoff).

## 6. Data Model
### 6.1 Entities
- `Sketch`
  - `id: String` (UUID)
  - `name: String`
  - `language: SketchLanguage` (`processingJava` or `p5js`)
  - `code: String`
  - `createdAt: int` (epoch ms)
  - `updatedAt: int` (epoch ms)

### 6.2 Constraints
- Unique sketch name (case-insensitive) enforced at repository layer and DB index.
- Non-empty code not required; new sketches initialized with starter template.
- Sketch language/runtime target is immutable after creation for MVP to keep editor and runtime assumptions simple.

### 6.3 Migration Strategy
- Schema versioning approach:
  - Drift migrations for each version bump.
- Backward compatibility policy:
  - Preserve user sketches across all minor/patch updates.
  - No destructive migration in production builds.

## 7. Runtime Design
- Script packaging/injection flow:
  1. Editor returns in-memory code snapshot and sketch language through JS bridge.
  2. Runtime module selects the p5.js shell or Processing Java WASM shell based on sketch language.
  3. For p5.js, runtime escapes/injects `sketch.js` into the local HTML shell and loads bundled `p5.min.js` from app assets.
  4. For Processing Java, runtime passes `Sketch.pde` code into the bundled WASM Processing Java runtime loader.
  5. Runtime webview loads content with an app-controlled asset base URL.
- Run lifecycle states: `idle -> starting -> running -> error -> stopped`
- Stop strategy (including long-loop handling):
  - Stop triggers `stopLoading()` + load blank shell.
  - Restart performs full shell reload with latest snapshot.
  - Watchdog timeout (3 seconds without first-frame signal) marks runtime unresponsive and offers force restart.
- Console and error line mapping:
  - Inject global `window.onerror` + `unhandledrejection` hooks.
  - Parse stack traces and map to `sketch.js` virtual line offsets.
  - Parse Processing Java compile/runtime diagnostics from the WASM runtime and map to `Sketch.pde` lines where metadata is available.

## 8. Mobile Viewport Strategy
- Canvas sizing mode(s):
  - MVP default: full-screen canvas.
  - Future: fit-to-container toggle in settings.
- Orientation change handling:
  - Flutter observes metrics/orientation changes and posts resize messages to runtime.
  - Runtime applies `resizeCanvas(windowWidth, windowHeight)`.
- Safe area/system UI overlap handling:
  - Use `SafeArea`/insets-aware layout for app chrome.
  - Runtime canvas occupies drawable content area.
- Performance safeguards on resize/redraw:
  - Debounce rapid resize events (100ms).
  - Avoid complete runtime reload on simple orientation flips unless recovery is needed.

## 9. Security and Isolation
- Web runtime bridge API surface:
  - `onRuntimeReady()`
  - `onRuntimeError(message, line, column, stack)`
  - `onConsole(level, message)`
- Input sanitization and message validation:
  - JSON-only bridge payloads with strict schema checks.
  - Truncate oversized console/error payloads.
- Restrictions on file/network/native access:
  - No generic `eval` bridge or arbitrary method dispatcher.
  - Block external URL loading in runtime webview for MVP.
  - Disallow file access outside bundled/local app-controlled content.
- Threat model summary:
  - Treat user code as untrusted; isolate in runtime webview and avoid privileged APIs.

## 10. Performance Plan
- Budgets from PRD:
  - Cold start <= 3s
  - Run-to-first-frame <= 1.5s
  - Typing latency target < 100ms
- Measurement approach and tooling:
  - Flutter integration benchmarks (`integration_test`) for startup/run timing.
  - DevTools frame profiling for jank analysis.
  - Custom telemetry for run start/first-frame.
- Performance test scenarios:
  - Simple animation sketch, medium particle sketch, erroring sketch.
  - Low-end and mid-range Android device profiles.

## 11. Testing Strategy
- Unit tests:
  - Domain entities/value objects, use cases, repository contracts, error parser.
- BLoC tests:
  - Event-to-state transitions for `SketchCatalogBloc`, `EditorBloc`, and `RuntimeBloc`.
- Integration tests:
  - Create/edit/save/run/delete flow with real infrastructure wiring and mocked bridge events.
- Device tests:
  - Orientation changes, background/foreground resume, process death restore.
- Acceptance test mapping to PRD criteria:
  - One integration/device test per PRD acceptance criterion, tracked in QA checklist.

## 12. Observability
- Crash reporting: Firebase Crashlytics with feature tags.
- Structured logs for runtime failures: app logs + optional persisted last-run diagnostics.
- Product metrics implementation for PRD success metrics:
  - Events: `sketch_created`, `run_tapped`, `run_started`, `run_first_frame`, `run_failed`, `sketch_deleted`.

## 13. Rollout Plan
- Internal alpha milestones:
  - Alpha 1: CRUD + editor save loop
  - Alpha 2: runtime run/stop/error console
  - Alpha 3: viewport/orientation hardening
- Beta gating criteria:
  - Crash-free sessions >=99.5% for 7-day beta window.
  - All PRD acceptance criteria pass on test matrix.
- Feature flags (if any):
  - `runtime_watchdog_enabled`
  - `editor_find_enabled`

## 14. Risks and Technical Mitigations
- Runtime inconsistencies across Android WebView versions -> maintain device/API test matrix and fallback compatibility mode.
- Processing Java WASM startup time, APK size, and diagnostic quality -> benchmark cold/warm start, track packaged asset size, and define best-effort line mapping for MVP.
- Editor performance regressions -> enforce extension budget and benchmark typing latency before releases.
- User script hangs -> watchdog detection + force restart UX + full reload recovery.

## 15. ADR Index
Track major technical decisions as ADRs.

| ADR ID | Title | Status | Date | Link |
|---|---|---|---|---|
| ADR-001 | Select app framework (Flutter) | Accepted | 2026-03-12 | docs/adr/ADR-001-framework.md |
| ADR-002 | Select runtime execution model (WebView sandbox) | Accepted | 2026-03-12 | docs/adr/ADR-002-runtime-model.md |
| ADR-003 | Select storage layer (Drift/SQLite) | Accepted | 2026-03-12 | docs/adr/ADR-003-storage.md |
| ADR-004 | Select architecture style (DDD) | Accepted | 2026-03-12 | docs/adr/ADR-004-architecture.md |
| ADR-005 | Select state management (BLoC) | Accepted | 2026-03-12 | docs/adr/ADR-005-state-management.md |

## 16. Open Technical Questions
- Should MVP keep runtime networking fully blocked, or allow opt-in external asset loading per sketch?
- Do we need a low-memory editor mode for devices below 4GB RAM?
- Should tablet layout (split editor/preview) be enabled in MVP or first post-MVP release?
