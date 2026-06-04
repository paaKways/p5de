# Milestone 3 Project Folders Record

## Status
- Implemented as an M3 extension with automated validation.
- Android project acceptance passed on the `dev` emulator.
- Follow-up catalog organization QA passed on Pixel 8 Pro `38041FDJG01HO5`.
- p5.js creation/runtime remains on hold indefinitely and is not part of this proposal.

## User Request
Add project CRUD as a sketch organization feature. A project is a folder in the app directory that contains code files. Projects are different from single-file sketches currently shown in the catalog.

## Proposed Behavior
- Users can create, read, update, and delete projects.
- A project maps to a top-level folder in the app directory.
- Project folders can be discovered from the app directory similarly to how sketch code files/folders are discovered today.
- In the current storage model, standalone sketches are also top-level folders. A top-level folder is treated as a project only when it is not itself a readable standalone sketch folder.
- The sketches page can show project list items.
- Opening a project list item opens a new project-detail screen.
- The project-detail screen lists top-level sketches contained directly in that project folder.
- Project-contained sketches are immediate child sketch folders under the project folder.
- Folders inside a project folder are not treated as nested projects.
- Nested folders may exist, but they should not appear as project list items inside the project-detail screen.
- New sketches created inside a project should use the current Processing Java-only creation path.

## Suggested M3 Placement
This was implemented after the Processing Java runtime smoke work was recorded as pending on the slow `dev` emulator.

## Confirmed Decisions
- Project metadata: Infer projects from top-level folders only. Do not require a project metadata file.
- Existing sketches: Keep current standalone sketches at the catalog root after project support lands.
- Delete behavior: Deleting a project permanently deletes the whole project folder and contained sketches.
- Rename behavior: Project rename moves the backing folder, with name collisions surfaced as user-visible errors.
- Search/filter behavior: Global search should show both projects and sketches inside projects.
- Nested folders: Ignore nested folders completely for project/sketch listing.
- Import/rescan behavior: Automatically rescan the app directory on launch for manually added project folders.

## Implementation Evidence
- Domain/application:
  - `lib/contexts/sketch_catalog/domain/project.dart`
  - `lib/contexts/sketch_catalog/domain/project_repository.dart`
  - `lib/contexts/sketch_catalog/application/create_project.dart`
  - `lib/contexts/sketch_catalog/application/rename_project.dart`
  - `lib/contexts/sketch_catalog/application/delete_project.dart`
  - `lib/contexts/sketch_catalog/application/list_favorite_project_sketches.dart`
  - `lib/contexts/sketch_catalog/application/list_favorite_sketches.dart`
  - `lib/contexts/sketch_catalog/application/list_projects.dart`
  - `lib/contexts/sketch_catalog/application/search_project_sketches.dart`
  - `lib/contexts/sketch_catalog/application/toggle_project_sketch_favorite.dart`
  - `lib/contexts/sketch_catalog/application/toggle_sketch_favorite.dart`
- Infrastructure:
  - `lib/contexts/sketch_catalog/infrastructure/filesystem_project_repository.dart`
  - `lib/contexts/sketch_catalog/infrastructure/in_memory_project_repository.dart`
  - `lib/contexts/sketch_catalog/infrastructure/project_scoped_sketch_repository.dart`
  - `lib/contexts/sketch_catalog/infrastructure/web_local_storage_project_repository.dart`
- Presentation:
  - `lib/contexts/sketch_catalog/presentation/sketch_catalog_bloc.dart`
  - `lib/contexts/sketch_catalog/presentation/sketch_catalog_page.dart`
  - `lib/contexts/sketch_catalog/presentation/project_detail_page.dart`
  - `lib/shared/updated_at_formatter.dart`

## Acceptance
- [x] User can create a project folder from the app.
- [x] User can rename a project and the backing folder is updated safely.
- [x] User can delete a project according to the approved delete behavior.
- [x] Sketches page distinguishes standalone sketches from projects.
- [x] Opening a project opens a project-detail screen.
- [x] Project-detail screen lists only top-level sketches directly inside the project folder.
- [x] Nested folders inside a project are not treated as nested projects.
- [x] Existing Processing Java sketch creation works inside a project.
- [x] Project folders are read from the app directory on app startup/rescan.
- [x] File/folder name collisions are handled with a user-visible error.
- [x] Android device QA verifies create, rename, delete, relaunch/rescan, and open-project flows.

## Follow-Up Catalog Integration
- [x] Standalone sketches can still be created directly from the sketches page.
- [x] The create action expands into New sketch and New project actions.
- [x] Runtime selection is not shown while Processing Java is the only active creation path.
- [x] Standalone sketches remain at the catalog root after project support lands.
- [x] All, Recent, and Favourites filters work from the sketches page.
- [x] Recent shows project folders as project rows, matching All.
- [x] Favourites shows favourite standalone sketches and favourite sketches inside projects.
- [x] Favourites uses optimized favourites-only repository calls.
- [x] Edited dates are readable on catalog rows.
- [x] Android mirrors app-private sketch folders to `/sdcard/Documents/p5de/sketches` for user access.

## Validation
- `flutter analyze --no-pub lib test` passed on 2026-05-25.
- `flutter test --no-pub` passed on 2026-05-25 with 53 tests.
- `flutter build web --no-pub` passed on 2026-05-25.
- Web build emitted existing wasm dry-run warnings for `dart:html` usage in editor/runtime web views; standard browser build completed successfully.
- `flutter build apk --debug --no-pub` passed on 2026-05-25 after rerunning outside the sandbox for Gradle cache/network access.
- Android `emulator-5554` smoke passed on 2026-05-25: create project, open project, create contained Processing Java sketch, relaunch/rescan persistence, global search for contained sketch, rename project, and delete project.
- Pixel 8 Pro `38041FDJG01HO5` smoke passed on 2026-05-25 for Recent project-row behavior and Favourites empty/one-starred-sketch behavior.
- A rename-dialog controller lifecycle regression was reproduced with a widget test and fixed before the Android rename smoke was rerun.
- Android final smoke screenshot: `m3-projects-final.png`.
