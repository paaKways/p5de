Place bundled CodeMirror module in this folder for offline/native/web use.
Expected file name:
- codemirror.js

Build command (from repo root):
- `powershell -ExecutionPolicy Bypass -File scripts/build_codemirror_modules.ps1`

Optional cleanup of temporary tooling files after build:
- `powershell -ExecutionPolicy Bypass -File scripts/build_codemirror_modules.ps1 -CleanTooling`
