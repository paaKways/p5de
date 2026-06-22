# Milestone 4 Acceptance Checklist

## Scope
- Milestone: Hardening and Beta Readiness
- Date: 2026-06-18 June local progress recorded; formal M4 acceptance pending
- Tester: pending
- Device/Emulator: Pixel 8 Pro `38041FDJG01HO5` used for June debug install; full device matrix pending
- Build/Commit: `dev`, base `2c7c0ea`, with June updates currently in the working tree; pending signed release candidate

## Preconditions
- Milestone 2 editor acceptance is complete before formal M4 acceptance starts. Status: pending.
- Milestone 3 Processing Java runtime acceptance is complete. Status: recorded on 2026-05-25.
- p5.js creation and runtime execution remain on hold indefinitely and are excluded from beta acceptance.
- Release-candidate build is signed and installable. Status: pending; a local release APK was built on 2026-06-18 but is not yet recorded as a signed or distributed release candidate.

## June 2026 Recorded Progress
- First-install SuaCode Africa folder/content seeding is implemented for first-time users only. Existing users and users who delete the seeded folder are not auto-seeded again and can recreate content through the Create Folder/Content flow.
- User-facing terminology now uses Folder instead of Project and Content instead of Project template. Internal code and historical records may still use project/template naming.
- Dashboard/catalog polish is implemented: the leading icon before "My Sketches" was removed, sketch list rows now use a curly-brace code icon, and the Recent filter reuses the loaded catalog when switching from All to Recent.
- Regression coverage was added for default content seeding and Recent-filter catalog reuse.
- Debug APK was rebuilt and installed on Pixel 8 Pro `38041FDJG01HO5`.
- Local release APK was built at `build/app/outputs/flutter-apk/app-release.apk` and measured at 59.7 MB.

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
- Notes: M4 hardening has started with telemetry/Crashlytics code wiring, first-install default content seeding, catalog terminology/UX polish, and a Recent-filter responsiveness fix. Firebase platform configuration is still pending because the repository does not yet include Android project config. M3 Processing Java runtime acceptance is recorded, and beta scope must continue to exclude p5.js runtime execution while it is on hold. Milestone 2 editor-specific Android acceptance is still a precondition before formal M4 acceptance. The June 18 release APK build is local build evidence only, not signed/distributed RC evidence.
- Follow-up defects/tasks: Populate with P0/P1 dispositions during M4.
