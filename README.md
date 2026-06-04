# p5de

Mobile Processing Java editor and runtime app built with Flutter. The p5.js path is on hold indefinitely.

## What It Does

- Create, edit, and run Processing Java sketches on Android.
- p5.js sketch creation and runtime execution are on hold indefinitely.
- Works offline with local persistence.
- Uses DDD + BLoC architecture across bounded contexts.

## Tech Stack

- Flutter
- Drift (SQLite)
- flutter_bloc
- InAppWebView (CodeMirror editor and Processing Java runtime host; p5.js runtime execution is on hold indefinitely)

## Current Status

- Milestone 0 accepted (foundation + CI + architecture skeleton).
- Milestone 1 accepted (Sketch catalog CRUD, Drift repository, BLoC, UI, and tests).
- Milestone 2 implementation is present (CodeMirror editor, draft/save flow, autosave wiring, and Processing Java language metadata); partial Android catalog smoke is recorded and editor-specific Android acceptance is pending.
- Milestone 3 is accepted for the Processing Java runtime scope, including Pixel runtime smoke and a first-frame timing record.
- M3 project folder CRUD, direct sketch/project create actions, catalog filters, readable dates, user-visible Android sketch mirroring, and favourites performance fixes are implemented with automated validation and Pixel QA.
- Milestone 4 hardening has started with telemetry and Crashlytics code wiring; real Firebase Android project config is still pending.
- p5.js sketch creation and runtime execution are on hold indefinitely.
- Detailed milestone records live in `docs/progress/README.md`.

## Quick Start

```powershell
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

For local Android device testing, make sure Flutter can find the Android SDK. On this machine the SDK is expected at:

```powershell
$env:ANDROID_HOME='D:\AndroidSdk'
$env:ANDROID_SDK_ROOT='D:\AndroidSdk'
$env:PATH='D:\AndroidSdk\platform-tools;' + $env:PATH
```

## Docs

- `docs/PRD.md`
- `docs/TDD.md`
- `docs/IMPLEMENTATION_PLAN.md`
- `docs/OBSERVABILITY.md`
