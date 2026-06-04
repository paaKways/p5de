# Progress Records

## Current Snapshot
- Date: 2026-05-25 Processing Java runtime acceptance and Pixel catalog QA
- Branch/commit: `dev`, `10542dc`
- Current milestone: Milestone 4 - Hardening and Beta Readiness
- Active runtime path: Processing Java
- p5.js path: Creation and runtime execution are on hold indefinitely. Do not schedule p5.js runtime or creation acceptance work until the roadmap explicitly resumes it.

## Milestone Status
| Milestone | Record | Acceptance | Status |
| --- | --- | --- | --- |
| M0 - Project Foundation | `M0_FOUNDATION.md` | `M0_ACCEPTANCE_CHECKLIST.md` | Accepted with CI follow-up carried forward |
| M1 - Sketch Catalog | `M1_FOUNDATION.md` | `M1_ACCEPTANCE_CHECKLIST.md` | Accepted |
| M2 - Editor Slice | `M2_FOUNDATION.md` | `M2_ACCEPTANCE_CHECKLIST.md` | Implemented; editor-specific Android acceptance pending |
| M3 - Runtime Preview Slice | `M3_FOUNDATION.md` | `M3_ACCEPTANCE_CHECKLIST.md` | Accepted for Processing Java runtime scope; project/catalog extension implemented |
| M4 - Hardening and Beta Readiness | `M4_FOUNDATION.md` | `M4_ACCEPTANCE_CHECKLIST.md` | Started; telemetry/Crashlytics code wiring implemented, Firebase platform config pending |

## Scope Notes
- Milestone 2 has implementation evidence in `lib/contexts/editor`, CodeMirror assets, Processing Java creation metadata, and editor bloc tests. The create-sketch catalog path now hides runtime/language selection and creates Processing Java sketches, but editor-specific Android acceptance is still pending.
- Before project-folder work, Milestone 3 was focused on Processing Java runtime preview: editor-to-runtime handoff, bundled runtime assets, JS bridge events, runtime state, console diagnostics, watchdog handling, run/stop/restart, first-frame timing, offline execution, and orientation/route-exit QA.
- The p5.js creation/runtime path is explicitly on hold indefinitely.
- Project folder CRUD and follow-up catalog organization work are implemented as an M3 extension with automated validation and Pixel QA. Details live in `M3_PROJECTS_PROPOSAL.md`.
- Processing Java runtime acceptance is recorded on Pixel 8 Pro `38041FDJG01HO5`; first observed run-to-first-frame sample is 7017 ms in a debug build using UIAutomator detection.
- M4 hardening has started with telemetry and Crashlytics code wiring. Event inventory and Firebase config notes live in `docs/OBSERVABILITY.md`.
- Milestone 4 can start beta-hardening planning now that M3 runtime acceptance is recorded, but formal M4 acceptance still depends on the remaining M4 entry criteria, including Milestone 2 editor-specific Android acceptance.
