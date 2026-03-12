# Product Requirements Document (PRD)
## Product: Mobile p5.js Editor & Runtime App
## Version: 1.0 (MVP)
## Date: March 12, 2026

## 1. Overview
A mobile-first app that lets users create, edit, organize, and run p5.js sketches directly on Android devices. The app combines a code editor, local project management, and a sandboxed runtime preview optimized for mobile viewports.

The primary value is enabling fast creative coding workflows on phones/tablets without needing a desktop environment.

## 2. Problem Statement
Current p5.js workflows are desktop/browser-centric and not optimized for mobile coding. Users who want to sketch ideas on the go face friction with:
- Poor mobile code editing UX
- No native project organization
- Inconsistent preview behavior on small screens
- Difficulty managing multiple sketches locally

## 3. Goals
- Allow users to create, edit, and delete p5.js scripts/projects from a mobile app.
- Run sketches reliably in a mobile-optimized runtime view.
- Provide a responsive coding and preview experience across common Android screen sizes.
- Enable offline-first usage for editing and running local scripts.

## 4. Non-Goals (MVP)
- Cloud sync/account system
- Real-time collaboration
- Third-party plugin ecosystem
- Full desktop IDE parity
- Publishing to app stores/web directly from the app

## 5. Target Users
- Students learning creative coding
- Hobbyist generative artists
- Educators demonstrating p5.js examples
- Developers prototyping visual ideas quickly on mobile

## 6. User Stories
1. As a user, I can create a new p5.js sketch with starter boilerplate so I can begin coding immediately.
2. As a user, I can view and open my saved sketches from a list.
3. As a user, I can edit sketch code in a mobile-friendly editor with syntax highlighting.
4. As a user, I can run a sketch and see output fit properly to my device screen.
5. As a user, I can stop/restart a running sketch after code changes.
6. As a user, I can delete a sketch I no longer need.
7. As a user, I can recover from runtime errors by seeing error messages linked to code lines.

## 7. Functional Requirements

### 7.1 Project Management
- Create sketch
  - User can create a sketch from:
    - Blank template
    - Default p5.js starter template (`setup()` + `draw()`)
  - Required fields: sketch name (unique in local storage)
- List sketches
  - Show sketches in a scrollable list with name, last modified time
  - Support search by sketch name
- Rename sketch
  - User can rename a sketch with duplicate-name validation
- Delete sketch
  - User can delete a sketch from list/details
  - App must show confirmation before delete

### 7.2 Code Editor
- Editor supports:
  - JavaScript syntax highlighting
  - Auto-indentation/basic bracket matching
  - Line numbers
  - Undo/redo
  - Find in file (MVP basic text search)
- Editing behaviors:
  - Auto-save on pause/background and at fixed debounce interval (e.g., 1 second)
  - Dirty state indicator when unsaved changes exist
- File model (MVP):
  - Single script file per sketch (`sketch.js`)
  - Optional support for `index.html`/`style.css` deferred post-MVP

### 7.3 Runtime/Compiler Experience
- Run action executes current sketch in an isolated WebView runtime.
- Runtime injects p5.js library and user `sketch.js`.
- Stop action halts execution and clears canvas.
- Restart action re-runs latest saved or in-memory code.
- Error handling:
  - Syntax/runtime errors shown in a console panel
  - Error message includes line/column when available

### 7.4 Mobile Viewport Rendering
- Runtime canvas should adapt to viewport using one of:
  - Full-screen canvas mode (default)
  - Fit-to-container mode
- Orientation changes (portrait/landscape) should trigger smooth resize and redraw.
- App should avoid clipped output and ensure gesture/system UI overlap is handled.
- Minimum target behavior:
  - Sketch remains visible and interactive after rotation
  - No app crash during resize events

### 7.5 UX & Navigation
- Primary screens:
  1. Sketch Library
  2. Editor
  3. Preview (can be split or tabbed with editor)
- Core actions accessible in <=2 taps from editor:
  - Run
  - Stop/Restart
  - Save
  - Delete (via menu)
- Display inline feedback for save status, runtime status, and errors.

## 8. Non-Functional Requirements

### 8.1 Performance
- App cold start: <=3 seconds on target mid-range Android device.
- Time from tapping Run to first frame: <=1.5 seconds for simple sketches.
- Editor input latency: no visible lag during normal typing (<100ms interaction response).

### 8.2 Reliability
- No data loss for saved sketches during normal lifecycle events (background/foreground, rotation).
- Crash-free sessions target: >=99.5% for MVP beta.

### 8.3 Offline Capability
- Full create/edit/run/delete workflow must work offline.
- p5.js runtime dependency should be bundled locally for offline execution.

### 8.4 Security & Isolation
- Runtime should restrict dangerous file/system access from user scripts.
- No arbitrary native code execution from sketch runtime.
- Validate/sanitize any bridge communication between app and WebView.

### 8.5 Accessibility
- Support dynamic font scaling in key UI text.
- Buttons and touch targets follow minimum touch size guidance (>=44dp).
- Color contrast should meet WCAG AA for text in standard themes.

## 9. MVP Scope
Included:
- Local sketch CRUD (create/read/update/delete)
- Single-file `sketch.js` editing with syntax highlighting
- Run/stop/restart preview
- Mobile viewport-adaptive rendering
- Error console with line-level info (best effort)

Excluded:
- Multi-file projects
- Cloud backup/sync
- Import/export to external storage providers
- Advanced linting/intellisense

## 10. Success Metrics
- Activation: >=70% of new users create first sketch in first session.
- Engagement: >=40% of active users run at least one sketch/session.
- Stability: crash-free sessions >=99.5%.
- Retention (D7): target >=20% for beta cohort.
- UX quality: <=5% sessions with failed run due to app/runtime issues (excluding user code errors).

## 11. Acceptance Criteria (MVP)
1. User can create a sketch, see it in list, open it, edit code, and save changes.
2. User can delete a sketch and it is removed from persistent storage.
3. User can run default p5 template and see animated output on phone screen.
4. Preview remains functional after orientation change.
5. Syntax/runtime errors are shown without crashing app.
6. Relaunching app preserves previously saved sketches.

## 12. Milestones
1. Foundation (Week 1-2)
- Project setup, local data model, sketch CRUD UI
2. Editor (Week 3-4)
- Mobile code editor integration, auto-save, basic search
3. Runtime (Week 5-6)
- WebView sandbox, p5 injection, run/stop/restart, error console
4. Viewport Optimization (Week 7)
- Rotation handling, full-screen fit behavior, perf tuning
5. Beta Hardening (Week 8)
- QA, crash fixes, telemetry, polish

## 13. Risks & Mitigations
- Risk: WebView runtime incompatibilities across devices
  - Mitigation: Test matrix across Android API/device profiles; fallback compatibility mode
- Risk: Editor lag on lower-end devices
  - Mitigation: Lightweight editor config; disable heavy features in MVP
- Risk: User code can freeze UI via expensive loops
  - Mitigation: Isolated runtime + manual stop + watchdog timeout handling

## 14. Open Questions
- Should MVP support tablet-specific split-screen editor + preview layout?
- Is import/export of `.js` files required for initial beta?
- Should autosave be always-on or user-configurable?
- Do we need a bundled gallery of sample sketches at launch?

## 15. Technical Assumptions (High-Level)
- The app is mobile-first and targets Android for MVP.
- A bundled local p5.js runtime is used so preview works offline.
- Runtime execution occurs in an isolated embedded web runtime (for example, a WebView-based sandbox), but exact implementation is defined in the TDD.
- Local persistence is required for sketch storage, with exact database/storage technology defined in the TDD.
- Exact framework, language, and library choices are intentionally deferred to `TDD.md` to keep this PRD implementation-agnostic.
