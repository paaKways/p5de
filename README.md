# p5de

Mobile p5.js editor and runtime app built with Flutter.

## What It Does

- Create, edit, and run p5.js sketches on Android.
- Works offline with local persistence.
- Uses DDD + BLoC architecture across bounded contexts.

## Tech Stack

- Flutter
- Drift (SQLite)
- flutter_bloc
- InAppWebView (for editor/runtime)

## Current Status

- Milestone 0 complete (foundation + CI + architecture skeleton).
- Milestone 1 foundation complete (Sketch domain/use cases/Drift repository baseline).

## Quick Start

```powershell
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

## Docs

- `docs/PRD.md`
- `docs/TDD.md`
- `docs/IMPLEMENTATION_PLAN.md`
