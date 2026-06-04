# Milestone 2 Acceptance Checklist

## Scope
- Milestone: Editor Slice
- Date: 2026-05-25 status reconciliation
- Tester: project team / Codex-assisted review
- Device/Emulator: Partial Android pass on `dev` emulator
- Build/Commit: Working tree on `dev` branch, base `10542dc`

## Preconditions
- Milestone 1 catalog acceptance is complete.
- At least one Processing Java sketch exists in the catalog.
- CodeMirror editor assets are bundled with the app.

## Functional Checks
- [x] Create dialog supports Processing Java only.
  - Expected: Runtime/language selection is hidden; creation implicitly uses Processing Java.
- [x] Processing Java sketches derive `.pde` file names.
  - Expected: Editor tab shows `Sketch.pde` or the sketch-name-derived `.pde` file name.
- [x] p5.js creation is disabled while the p5.js path is on hold.
  - Expected: New sketches created through the catalog use Processing Java metadata.
- [x] User can open a catalog sketch into the editor route.
  - Expected: Catalog tile navigation opens `EditorPage`.
- [x] Editor loads saved sketch code into a clean draft.
  - Expected: Initial editor state is ready and not dirty.
- [x] Editor tracks dirty state after code changes.
  - Expected: Dirty indicator appears and save becomes available.
- [x] Manual save persists code changes.
  - Expected: Saved draft becomes clean and repository code is updated.
- [x] Debounced autosave request is wired after typing changes.
  - Expected: Editor schedules save after a one-second typing pause.
- [x] Lifecycle save request is wired for inactive/paused/detached app states.
  - Expected: Dirty draft requests save before the app leaves active state.
- [ ] CodeMirror syntax highlighting is verified on Android for Processing Java.
  - Expected: Editor renders usable highlighting and input behavior for `.pde`.
- [ ] App background/foreground autosave is manually verified on Android.
  - Expected: Edited code survives background/foreground and app relaunch.

## UX Checks
- [x] Editor exposes undo, redo, run, save, find, and symbol insertion controls.
- [x] Editor shows file name, language label, cursor position, and save/dirty status.
- [ ] Long sketch names and small mobile widths are manually checked for overflow.
- [ ] Back navigation discard prompt is manually checked with unsaved changes.

## Result Summary
- Overall: `Implementation Complete - Partial Manual Acceptance Recorded`
- Notes: Code and automated tests support the editor slice. Android catalog create smoke verified that new sketches are Processing Java only and p5.js is not offered. Editor-specific Android acceptance evidence still needs to be recorded before marking this milestone accepted.
- Follow-up defects/tasks:
  - Complete manual Android editor QA.
  - Record final device/build details after acceptance.
