param(
  [switch]$CleanTooling
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$toolDir = Join-Path $repoRoot ".tooling/codemirror-build"
$entryDir = Join-Path $toolDir "entries"
$outDir = Join-Path $repoRoot "assets/editor/codemirror"

$packages = @(
  "@codemirror/state@6.5.2",
  "@codemirror/view@6.38.6",
  "@codemirror/commands@6.10.0",
  "@codemirror/language@6.11.3",
  "@codemirror/lang-javascript@6.2.4",
  "@codemirror/theme-one-dark@6.1.3",
  "esbuild@0.25.10"
)

function Assert-Command([string]$name) {
  if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
    throw "Missing required command '$name'. Install Node.js/npm first."
  }
}

Assert-Command "npm"
Assert-Command "npx"

New-Item -ItemType Directory -Force -Path $toolDir | Out-Null
New-Item -ItemType Directory -Force -Path $entryDir | Out-Null
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

Push-Location $toolDir
try {
  if (-not (Test-Path (Join-Path $toolDir "package.json"))) {
    npm init -y | Out-Null
  }

  Write-Host "Installing CodeMirror build dependencies..."
  npm install --no-audit --no-fund --save-exact @packages

  $entryPath = Join-Path $entryDir "codemirror.js"
  $outputPath = Join-Path $outDir "codemirror.js"

  # Bundle all required CodeMirror APIs together so runtime uses one module graph,
  # avoiding duplicate @codemirror/state instances.
  @"
export { EditorState } from '@codemirror/state';
export {
  EditorView,
  keymap,
  lineNumbers,
  highlightActiveLine,
  drawSelection,
  dropCursor,
  rectangularSelection,
  crosshairCursor,
  highlightActiveLineGutter,
} from '@codemirror/view';
export { defaultKeymap, history, historyKeymap, indentWithTab } from '@codemirror/commands';
export {
  bracketMatching,
  indentOnInput,
  syntaxHighlighting,
  defaultHighlightStyle,
} from '@codemirror/language';
export { javascript } from '@codemirror/lang-javascript';
export { oneDark } from '@codemirror/theme-one-dark';
"@ | Set-Content -Encoding UTF8 $entryPath

  Write-Host "Bundling codemirror.js..."
  npx esbuild $entryPath `
    --bundle `
    --format=esm `
    --platform=browser `
    --target=es2020 `
    --outfile=$outputPath `
    --log-level=warning
}
finally {
  Pop-Location
}

if ($CleanTooling) {
  Remove-Item -Recurse -Force $toolDir
  Write-Host "Cleaned tooling folder: $toolDir"
}

Write-Host "Done. Generated file: $outDir/codemirror.js"
