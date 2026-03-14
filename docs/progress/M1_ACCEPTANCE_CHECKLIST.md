# Milestone 1 Acceptance Checklist

## Scope
- Milestone: Sketch Catalog (CRUD)
- Date:
- Tester:
- Device/Emulator:
- Build/Commit:

## Preconditions
- App installed and launches successfully.
- Local database starts empty (fresh install) or state is known.

## Functional Checks
- [x] Create sketch with valid name.
  - Expected: Sketch appears in list immediately.
- [x] Create sketch with duplicate name (case-insensitive).
  - Expected: Error message shown, duplicate not created.
- [x] Create sketch with empty/whitespace name.
  - Expected: Validation error shown.
- [x] Search with partial match.
  - Expected: Matching sketches shown only.
- [x] Clear search query.
  - Expected: Full sketch list restored.
- [x] Rename existing sketch to a valid unique name.
  - Expected: Name updates in list.
- [x] Rename sketch to duplicate name.
  - Expected: Error message shown, rename blocked.
- [x] Delete sketch and confirm.
  - Expected: Sketch removed from list.
- [x] Delete sketch and cancel.
  - Expected: Sketch remains in list.

## Persistence Checks
- [x] Create at least 2 sketches, rename 1, then fully close app.
  - Expected: On reopen, sketches and renamed value are preserved.
- [x] Delete 1 sketch, close app, reopen.
  - Expected: Deleted sketch does not return.

## Lifecycle/UX Checks
- [ ] Rotate device while on catalog screen.
  - Expected: No crash; state remains usable.
- [ ] Background and foreground app from catalog screen.
  - Expected: No crash; list and search state remain consistent.
- [x] Empty-state messaging.
  - Expected: Clear "No sketches yet." when catalog is empty.
- [x] Action feedback.
  - Expected: Errors and confirmations are understandable.

## Result Summary
- Overall: `Pass`
- Notes: Tests were done on web so mobile specific tasks were not done but so far everything is okay
- Follow-up defects/tasks: None
