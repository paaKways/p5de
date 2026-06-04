# Observability

## Runtime Behavior
- App startup initializes `FirebaseAppTelemetry`.
- If Firebase platform configuration is missing or invalid, telemetry falls back to `NoopAppTelemetry` so local/debug builds keep running.
- Crashlytics collection defaults to release builds only. For an explicit debug verification run, pass `--dart-define=P5DE_CRASHLYTICS_ENABLED=true`.

## Crashlytics Tags
- `current_screen`
- `current_sketch_id`
- `current_project_id`
- `current_language`
- `runtime_status`
- `app_runtime`

## Telemetry Events
- `app_open`
- `catalog_search`
- `catalog_filter_change`
- `project_create`, `project_open`, `project_rename`, `project_delete`
- `sketch_create`, `sketch_open`, `sketch_rename`, `sketch_delete`
- `sketch_favorite_toggle`
- `project_sketch_open`
- `editor_open`, `editor_edit`, `editor_save`, `editor_command`
- `runtime_open`, `runtime_run`, `runtime_first_frame`, `runtime_restart`, `runtime_stop`
- `runtime_error`, `runtime_watchdog_timeout`

## Android Firebase Config Still Needed
The code wiring is present, but Android cannot send events or crash reports until a Firebase project is connected:
- add `android/app/google-services.json`
- add the Google Services and Crashlytics Gradle plugins for the Android app
- confirm the production `applicationId`
- run a debug verification with `P5DE_CRASHLYTICS_ENABLED=true`, then disable debug collection again
