# Milestone 3 Acceptance Checklist

## Scope
- Milestone: Runtime Preview Slice
- Date: 2026-05-25 runtime acceptance, Pixel catalog QA, and M3 scope reset
- Tester: project team / Codex-assisted review
- Device/Emulator: Pixel 8 Pro `38041FDJG01HO5`; prior project-folder pass on `dev` emulator
- Build/Commit: Working tree on `dev` branch, base `10542dc`

## Active Scope
- Processing Java runtime preview is in scope.
- p5.js creation and runtime preview are on hold indefinitely and are excluded from this acceptance checklist.
- Project folders and catalog organization changes are tracked as an M3 extension, not as a replacement for runtime acceptance.

## Preconditions
- Milestone 2 editor implementation is available.
- A Processing Java sketch can be opened in the editor.
- Processing Java runtime assets are bundled locally.
- Device is offline or network-disabled for at least one smoke pass to verify bundled runtime behavior.

## Functional Checks
- [x] Editor run action opens runtime preview with the current editor code snapshot.
  - Expected: Runtime route receives a sketch copy and current code.
- [x] Processing Java runtime shell is bundled.
  - Expected: Runtime WebView loads `assets/runtime/processing_java/runtime.html`.
- [x] Runtime bridge emits ready, status, log, error, and first-frame events.
  - Expected: Dart handlers map JS events into runtime UI state.
- [x] Runtime state tracks compile, load, run, stop, and failure states.
  - Expected: `RuntimePreviewBloc` updates state and console entries.
- [x] Compiler diagnostics are mapped into console entries.
  - Expected: Diagnostics include best-effort `Sketch.pde` line references.
- [x] Default Processing Java template runs on Android.
  - Expected: User sees animated output in runtime preview.
  - Evidence: Pixel 8 Pro smoke with `M3TimingSmoke194451.pde` reached runtime state `Running` with `Processing Java Runtime`, `TeaVM Output`, `Restart`, and `Stop` visible.
- [x] Run-to-first-frame timing is recorded.
  - Expected: Simple Processing Java sketch timing is captured and documented.
  - Evidence: Debug build on Pixel 8 Pro, editor Run tap to first UIAutomator dump containing `content-desc="Running"`: 7017 ms. Artifact: `artifacts/android-runtime-first-frame-20260525-195304-rerun`.
- [x] Stop button halts the active runtime.
  - Expected: Preview returns to stopped state without app crash.
  - Evidence: Pixel post-timing Stop action changed runtime state to `Stopped`; artifact `runtime-stopped.xml` is in `artifacts/android-runtime-first-frame-20260525-195304-rerun`.
- [x] Restart button reruns the current sketch.
  - Expected: Runtime resets and reaches first frame again.
  - Evidence: Working in user-observed Pixel smoke on 2026-05-25.
- [x] Back navigation stops runtime before leaving preview.
  - Expected: Route closes cleanly after runtime stop attempt.
  - Evidence: Working in user-observed Pixel smoke on 2026-05-25.
- [x] Orientation handling is verified.
  - Expected: Runtime preview stays usable through configured landscape orientation behavior.
  - Evidence: Pixel runtime smoke covered portrait editor to landscape runtime behavior.
- [x] Offline execution is verified.
  - Expected: Runtime runs from bundled assets without network access.
  - Evidence: Working in user-observed Pixel smoke on 2026-05-25; runtime shell is bundled under `assets/runtime/processing_java`.
- [x] Runtime watchdog/unresponsive recovery UX is implemented.
  - Expected: Runtime stops and records a console failure if Processing Java does not reach first frame within 60 seconds.

## Out Of Scope / On Hold
- p5.js runtime shell and bundled p5.js execution.
- p5.js creation from the catalog.
- p5.js run/stop/restart acceptance.
- p5.js first-frame and runtime console acceptance.

## Project Folders Extension
- [x] Project folder CRUD is implemented with automated validation.
- [x] Sketches page distinguishes standalone sketches from projects.
- [x] Opening a project opens a project-detail screen.
- [x] Project-detail screen lists only immediate child sketch folders directly inside the project folder.
- [x] Nested folders inside a project are ignored for project/sketch listing.
- [x] Global search includes projects and sketches inside projects.
- [x] Android device QA verifies project create, rename, delete, relaunch/rescan, and open-project flows.
- Record: `docs/progress/M3_PROJECTS_PROPOSAL.md`.

## Catalog Organization Follow-Up
- [x] User can create a standalone sketch directly without first creating a project.
- [x] Create FAB expands to separate New sketch and New project actions.
- [x] Runtime/language dropdown is hidden during sketch creation.
- [x] All, Recent, and Favourites filters are implemented.
- [x] Recent keeps project folders as project rows and does not auto-open both project and editor.
- [x] Favourites includes standalone favourites and project-contained sketch favourites.
- [x] Favourites uses a favourites-only data path instead of loading every project sketch and filtering afterward.
- [x] Edited dates render in readable short form, such as relative labels for recent edits and `12 Apr` style labels for older same-year edits.
- [x] App-private sketch folders are mirrored to `/sdcard/Documents/p5de/sketches` for user-visible access on Android.
- [x] Pixel 8 Pro QA verifies empty Favourites and one-starred-sketch Favourites behavior without visible hang.

## Result Summary
- Overall: `Accepted for Processing Java runtime scope`
- Notes: Processing Java runtime implementation and automated state tests are present. `flutter analyze --no-pub lib test`, full `flutter test --no-pub`, debug APK build, Android project-folder smoke, Pixel catalog filter QA, and Pixel Processing Java runtime smoke passed on 2026-05-25. Catalog creation now hides runtime/language selection and new sketches use Processing Java metadata. First-frame timing is recorded as a single debug-build UIAutomator observation, so M4 should replace it with a repeatable performance baseline.
- Follow-up defects/tasks:
  - Carry repeatable run/restart timing and broader device performance checks into M4.
