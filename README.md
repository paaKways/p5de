# p5de

Mobile Processing Java & p5.js editor and runtime app built with Flutter.

## What It Does

- Create, edit, and run Processing Java and p5.js sketches on Android.
- Works offline with local persistence.
- Uses DDD + BLoC architecture across bounded contexts.

## Tech Stack

- Flutter
- Drift (SQLite)
- flutter_bloc
- InAppWebView (planned for CodeMirror editor, p5.js runtime, and Processing Java WASM runtime host)

## Current Status

- Milestone 0 complete (foundation + CI + architecture skeleton).
- Milestone 1 mostly complete (Sketch catalog CRUD, Drift repository, BLoC, UI, and tests).
- Milestone 2 is next: CodeMirror editor integration, draft/autosave flow, and sketch language metadata for Processing Java (`Sketch.pde`) and p5.js (`sketch.js`).
- Runtime work is not implemented yet. The plan is to support p5.js through bundled web assets and Processing Java through a bundled WASM runtime.

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
