# Milestone 2 Acceptance Checklist

## Scope
- Milestone: Editor Slice (load/edit/autosave/save indicator)
- Date:
- Tester:
- Device/Emulator:
- Build/Commit:

## Preconditions
- At least one sketch exists in catalog.
- App launches successfully and editor screen is reachable.
- For Android validation: run on emulator/device (not web fallback).

## Functional Checks
- [x] Open sketch from catalog into editor.
  - Expected: Correct sketch title and code are loaded.
- [x] Edit code text in editor.
  - Expected: Editor updates immediately; no typing lag spikes.
- [ ] Save indicator after typing.
  - Expected: Shows `Unsaved changes`, then transitions to `Saving...`, then `Saved HH:MM`.
- [ ] Manual save button behavior.
  - Expected: Enabled only when dirty; disabled after save completes.
- [ ] Reopen same sketch from catalog.
  - Expected: Latest saved code is shown.

## CodeMirror Host Checks (Android Native Path)
- [x] CodeMirror host active in native editor.
  - Expected: Line numbers visible, syntax highlighting present.
- [x] Bridge update flow.
  - Expected: Flutter receives edits continuously via `onEditorCodeChanged`.
- [x] Fallback safety.
  - Expected: If CodeMirror modules fail to load, textarea editor still works (no crash).

## Autosave and Lifecycle Checks
- [x] Debounced autosave on typing pause.
  - Expected: Changes persist without explicit save after short idle.
- [x] Background then foreground app while editing.
  - Expected: No crash; draft/saved state remains consistent.
- [x] Rotate device while editor is open.
  - Expected: No crash; content preserved and editor remains usable.

## Result Summary
- Overall: `Pending`
- Notes:
- Follow-up defects/tasks:
