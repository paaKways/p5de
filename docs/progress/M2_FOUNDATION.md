# Milestone 2 Foundation Record

## Milestone
- Name: Milestone 2 - Editor Slice
- Source: `docs/IMPLEMENTATION_PLAN.md`
- Last updated: 2026-05-25 (status reconciled)

## Status
- Implementation status: Complete enough to hand off to runtime work.
- Acceptance status: Fresh Android manual acceptance pending.
- Runtime note: p5.js creation and runtime execution are on hold indefinitely. Processing Java is the only user-selectable creation/runtime path.

## Scope Checklist
- [x] Integrate CodeMirror 6 inside `InAppWebView`.
- [x] Implement editor bridge adapter for code changes, cursor changes, focus, insert text, undo, redo, and find.
- [x] Implement draft model and editor save policy.
- [x] Implement `EditorBloc`.
- [x] Implement use cases:
  - `LoadSketchForEdit`
  - `SaveSketch`
- [x] Add sketch language/runtime metadata for Processing Java (`Sketch.pde`).
- [x] Implement debounced autosave request on typing pause.
- [x] Implement lifecycle-triggered save request on inactive/paused/detached app states.
- [x] Add save/dirty-state indicators in the editor UI.
- [x] Add editor bloc tests.
- [ ] Complete fresh device acceptance for editor syntax highlighting, autosave, and lifecycle behavior.

## Evidence
- Editor domain/application:
  - `lib/contexts/editor/domain/editor_draft.dart`
  - `lib/contexts/editor/application/load_sketch_for_edit.dart`
  - `lib/contexts/editor/application/save_sketch.dart`
- Editor presentation:
  - `lib/contexts/editor/presentation/editor_bloc.dart`
  - `lib/contexts/editor/presentation/editor_event.dart`
  - `lib/contexts/editor/presentation/editor_state.dart`
  - `lib/contexts/editor/presentation/editor_page.dart`
  - `lib/contexts/editor/presentation/codemirror_editor_view.dart`
  - `lib/contexts/editor/presentation/codemirror_editor_view_io.dart`
  - `lib/contexts/editor/presentation/codemirror_editor_view_web.dart`
- CodeMirror assets:
  - `assets/editor/codemirror/editor.html`
  - `assets/editor/codemirror/editor.bundle.js`
- Sketch language metadata:
  - `lib/contexts/sketch_catalog/domain/sketch_language.dart`
  - `lib/contexts/sketch_catalog/application/sketch_templates.dart`
  - `lib/contexts/sketch_catalog/presentation/sketch_catalog_page.dart`
- Tests:
  - `test/contexts/editor/presentation/editor_bloc_test.dart`
  - `test/contexts/sketch_catalog/domain/sketch_language_test.dart`
  - `test/widget_test.dart`

## Validation Status
- Automated test coverage exists for editor bloc load/dirty/save/not-found transitions.
- Automated test coverage exists for sketch language file naming and catalog runtime selection.
- `flutter analyze --no-pub lib test` passed on 2026-05-25.
- Full `flutter test --no-pub` passed on 2026-05-25 with 53 tests.

## Remaining Milestone 2 Work
- Complete manual Android acceptance checklist in `docs/progress/M2_ACCEPTANCE_CHECKLIST.md`.
- Record build/device details after manual acceptance.

## Handoff To Milestone 3
- Runtime preview can consume the editor's current code snapshot.
- Runtime dispatch is currently meaningful for Processing Java only.
- p5.js creation and runtime execution are on hold indefinitely and should not block Processing Java runtime acceptance.
