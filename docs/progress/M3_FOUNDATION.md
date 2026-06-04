# Milestone 3 Foundation Record

## Milestone
- Name: Milestone 3 - Runtime Preview Slice
- Source: `docs/IMPLEMENTATION_PLAN.md`
- Last updated: 2026-05-25 (Processing Java runtime acceptance recorded)

## Status
- Implementation status: Implemented and accepted for Processing Java runtime scope.
- Original M3 focus: Processing Java runtime preview and runtime acceptance.
- Extension status: Project folders and catalog organization polish implemented and QA-recorded.
- Active runtime target: Processing Java.
- p5.js path: Creation and runtime execution are on hold indefinitely.

## Scope Decision
The runtime preview milestone is currently scoped to Processing Java execution only. p5.js creation and runtime execution are paused indefinitely and should not block Processing Java runtime acceptance.

## What M3 Was Before Projects
Before project folders were added, M3 was focused on getting the Processing Java runtime preview accepted on Android:
- editor run action hands the current code snapshot to runtime preview
- Processing Java WebView runtime shell and local assets are bundled
- JS bridge events report ready/status/log/error/first-frame back to Dart
- runtime state tracks compile, run, stop, restart, failure, and watchdog timeout
- console/error UI shows Processing Java diagnostics with best-effort `Sketch.pde` line mapping
- manual QA verifies default-template execution, stop, restart, back navigation, offline operation, orientation behavior, and run-to-first-frame timing

Project folders were added later as a catalog organization extension. They do not replace the runtime acceptance gate.

## Scope Checklist
- [ ] Add runtime HTML shell and bundled assets for p5.js.
  - Status: On hold indefinitely.
- [x] Add runtime HTML shell for Processing Java.
- [x] Add bundled Processing Java compiler/runtime assets.
- [x] Implement Processing Java runtime WebView adapter.
- [x] Implement JS bridge handlers for runtime ready/status/log/error/first-frame events.
- [x] Implement `RuntimePreviewBloc` for runtime status, console output, errors, first frame, and stop state.
- [x] Add run/restart/stop controls for Processing Java preview.
- [x] Add console/error UI.
- [x] Map Processing Java compiler diagnostics back to `Sketch.pde` line data where available.
- [x] Add runtime watchdog and unresponsive recovery UX.
- [x] Complete manual Android Processing Java runtime acceptance.
- [x] Record run-to-first-frame timing evidence.
- [x] Complete orientation and route-exit QA for runtime preview.

## Evidence
- Runtime presentation:
  - `lib/contexts/runtime_preview/presentation/runtime_preview_page.dart`
  - `lib/contexts/runtime_preview/presentation/runtime_preview_bloc.dart`
  - `lib/contexts/runtime_preview/presentation/runtime_preview_event.dart`
  - `lib/contexts/runtime_preview/presentation/runtime_preview_state.dart`
  - `lib/contexts/runtime_preview/presentation/runtime_preview_view.dart`
  - `lib/contexts/runtime_preview/presentation/runtime_preview_view_io.dart`
  - `lib/contexts/runtime_preview/presentation/runtime_preview_view_web.dart`
- Runtime domain:
  - `lib/contexts/runtime_preview/domain/runtime_console_entry.dart`
- Processing Java runtime assets:
  - `assets/runtime/processing_java/runtime.html`
  - `assets/runtime/processing_java/runtime.css`
  - `assets/runtime/processing_java/runtime_shell.js`
  - `assets/runtime/processing_java/src/teavmJavacAdapter.js`
  - `assets/runtime/processing_java/src/wasmProcessingCompiler.js`
  - `assets/runtime/processing_java/vendor/teavm-javac/*`
- Editor-to-runtime handoff:
  - `lib/contexts/editor/presentation/editor_page.dart`
- Tests:
  - `test/contexts/runtime_preview/presentation/runtime_preview_bloc_test.dart`
- Runtime hold behavior:
  - `lib/contexts/editor/presentation/editor_page.dart`
- Android smoke evidence:
  - `m3-after-create.png`
  - `m3-projects-final.png`
  - `android-recent-project-rows.png`
  - `android-filter-favourites.png`
  - `artifacts/android-runtime-first-frame-20260525-194451`
  - `artifacts/android-runtime-first-frame-20260525-195304-rerun`

## Validation Status
- Automated test coverage exists for runtime status transitions, mapped compiler diagnostics, and watchdog timeout behavior.
- `flutter analyze --no-pub lib test` passed on 2026-05-25.
- Full `flutter test --no-pub` passed on 2026-05-25 with 53 tests.
- `flutter build apk --debug --no-pub` passed on 2026-05-25 and the APK installed on Android test targets.
- Android catalog creation hides runtime/language selection and newly created sketches use Processing Java metadata.
- Android project-folder QA passed on `emulator-5554`: create project, open project, create contained Processing Java sketch, relaunch/rescan persistence, global search for contained sketch, rename project, and delete project.
- Pixel 8 Pro QA passed on `38041FDJG01HO5` for catalog filter behavior:
  - Recent keeps project folders as project rows.
  - Favourites opens without a visible hang for an empty favourites set.
  - Favourites opens directly to a starred sketch after temporarily starring `assignment 4`.
  - Favourites transition frame stats for the one-starred-sketch run: 1 rendered frame, 0 janky frames, 5 ms.
- Pixel 8 Pro QA passed on `38041FDJG01HO5` for the Processing Java default-template runtime smoke: run, stop, restart, back navigation, orientation behavior, and offline bundled-runtime execution were recorded as working on 2026-05-25.
- Runtime first-frame timing sample: `M3TimingSmoke194451.pde`, debug build, editor Run tap to first UIAutomator dump containing `content-desc="Running"`: 7017 ms. Artifact: `artifacts/android-runtime-first-frame-20260525-195304-rerun`.
- The timing sample is a coarse UIAutomator observation, not a repeatable performance benchmark. M4 should promote it into a proper run/restart timing baseline.

## Remaining Milestone 3 Work
Runtime acceptance left:
- No known Processing Java runtime acceptance items remain open after the Pixel smoke and timing record.

Project/catalog extension left:
- No known M3 project/catalog tasks are open after Pixel filter QA.

Scope hold:
- Keep p5.js creation and runtime execution on hold indefinitely unless the roadmap is explicitly changed.

Carry-forward to M4:
- Build a repeatable run/restart timing baseline from the M3 first-frame observation.
- Run the broader M4 performance, reliability, background/foreground, process-death, telemetry, and release-candidate matrix.

## M3 Project Folders Extension
- Project folder CRUD is implemented with automated validation.
- Record: `docs/progress/M3_PROJECTS_PROPOSAL.md`
- Projects are inferred from top-level folders only, with no project metadata file.
- Because standalone sketches are already top-level folders in the current storage model, a top-level folder is treated as a project only when it is not itself a readable standalone sketch folder.
- Opening a project shows a new screen listing only immediate child sketch folders directly inside that project folder.
- Nested folders inside a project are ignored for project/sketch listing.
- Project deletion removes the whole folder and contained sketches.
- Project rename moves the backing folder and surfaces collisions as user-visible errors.
- Global search includes projects and sketches inside projects.
- Browser builds use `WebLocalStorageProjectRepository` so project folders and project-contained sketches persist through browser local storage while running on web.
- Android device QA for project create/rename/delete/relaunch/open-project flows passed on `emulator-5554`.
- Follow-up catalog polish is implemented: direct standalone sketch creation, expandable create FAB, All/Recent/Favourites filters, readable edited dates, user-visible Documents mirror, and optimized favourites loading.

## Handoff To Milestone 4
- Milestone 3 Processing Java runtime acceptance is recorded.
- Milestone 4 can start beta-hardening planning, but formal M4 acceptance still needs the remaining M4 entry criteria, including editor-specific Android acceptance from Milestone 2.
- Beta scope must explicitly state that p5.js creation/runtime execution is excluded while on hold.
