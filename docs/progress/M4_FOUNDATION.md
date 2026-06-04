# Milestone 4 Foundation Record

## Milestone
- Name: Milestone 4 - Hardening and Beta Readiness
- Source: `docs/IMPLEMENTATION_PLAN.md`
- Last updated: 2026-05-25 (M3 runtime acceptance recorded)

## Status
- Implementation status: Started.
- Acceptance status: Not started.
- Dependency: Milestone 3 Processing Java runtime acceptance is recorded; Milestone 2 editor-specific Android acceptance is still pending before formal M4 acceptance.
- Scope note: p5.js creation and runtime execution are on hold indefinitely and must be excluded from beta-readiness criteria unless the roadmap changes.

## Scope Checklist
- [ ] Performance tune against TDD budgets.
- [ ] Complete orientation QA.
- [ ] Complete background/foreground QA.
- [ ] Complete process-death recovery QA.
- [x] Add telemetry events.
- [x] Add Crashlytics tagging in app/runtime flows.
- [ ] Add project-level Firebase platform configuration.
- [ ] Polish UX and fix P0/P1 defects.
- [ ] Sign release candidate.
- [ ] Distribute release candidate to testers.

## Evidence
- Firebase SDK dependencies were added during Milestone 0.
- Milestone 3 Processing Java runtime acceptance was recorded on Pixel 8 Pro `38041FDJG01HO5` on 2026-05-25.
- Telemetry and Crashlytics code wiring added:
  - guarded Firebase startup with no-op fallback when platform config is absent
  - global Flutter/platform error recording
  - Crashlytics custom keys for screen, sketch, project, language, and runtime status
  - telemetry events for create, edit, save, run, stop, restart, runtime first frame, and runtime failure
  - event inventory in `docs/OBSERVABILITY.md`
- No release-candidate validation or broader M4 manual QA matrix evidence is recorded yet.

## Entry Criteria
- [ ] Milestone 2 editor acceptance recorded.
- [x] Milestone 3 Processing Java runtime acceptance recorded.
- [x] p5.js creation/runtime hold decision reflected in beta scope.
- [ ] No known P0 defects open.

## Remaining Milestone 4 Work
- Close the Milestone 2 editor-specific Android acceptance record.
- Define beta scope around accepted Processing Java runtime capabilities.
- Decide whether p5.js editing without runtime execution remains visible in beta or is hidden behind product copy/settings.
- Add real Firebase Android project config (`google-services.json`) and Android Gradle plugin wiring.
- Run full validation and manual QA matrix.
- Record final release-candidate build metadata.
