# Milestone 4 Acceptance Checklist

## Scope
- Milestone: Hardening and Beta Readiness
- Date: 2026-05-25 M3 runtime acceptance recorded
- Tester: pending
- Device/Emulator: pending device matrix
- Build/Commit: pending release candidate

## Preconditions
- Milestone 2 editor acceptance is complete before formal M4 acceptance starts. Status: pending.
- Milestone 3 Processing Java runtime acceptance is complete. Status: recorded on 2026-05-25.
- p5.js creation and runtime execution remain on hold indefinitely and are excluded from beta acceptance.
- Release-candidate build is signed and installable.

## Functional Regression Checks
- [ ] Create, list, search, rename, and delete sketches.
- [ ] Persist sketches across app relaunch.
- [ ] Open Processing Java sketches in editor.
- [ ] Save and autosave editor changes.
- [ ] Run, stop, and restart Processing Java sketches.
- [ ] Show Processing Java compiler/runtime errors in console.
- [ ] Confirm p5.js creation and runtime execution are not presented as available while on hold.

## Reliability Checks
- [ ] Orientation changes do not crash catalog/editor/runtime flows.
- [ ] Background/foreground transitions preserve expected state.
- [ ] Process restart or cold launch recovers persisted sketches.
- [ ] Runtime route exit stops runtime cleanly.
- [ ] No open P0 defects.
- [ ] P1 defects have explicit disposition.

## Performance Checks
- [ ] Editor typing responsiveness is within target on mid-range device.
- [ ] Processing Java run-to-first-frame timing is recorded.
- [ ] Runtime restart timing is recorded.
- [ ] APK size impact from bundled runtime assets is reviewed.

## Telemetry / Crash Reporting Checks
- [ ] Firebase platform configuration is complete for target build.
- [x] Crashlytics tagging is present for key app/runtime flows.
- [x] Telemetry events are present for create, edit, save, run, stop, restart, and runtime failure.

## Release Checks
- [ ] Release candidate is signed.
- [ ] Release candidate is distributable to testers.
- [ ] Smoke test passes on device matrix.
- [ ] Known limitations are documented, including indefinite p5.js runtime hold.

## Result Summary
- Overall: `Pending`
- Notes: M4 hardening has started with telemetry/Crashlytics code wiring. Firebase platform configuration is still pending because the repository does not yet include Android project config. M3 Processing Java runtime acceptance is recorded, and beta scope must continue to exclude p5.js runtime execution while it is on hold. Milestone 2 editor-specific Android acceptance is still a precondition before formal M4 acceptance.
- Follow-up defects/tasks: Populate with P0/P1 dispositions during M4.
