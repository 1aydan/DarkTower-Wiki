# Dark Tower wiki — full static build into Wiki/site/.
# Steps: sync design docs -> run Doxygen -> build MkDocs site.

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot

# Silence the MkDocs 2.0 banner mkdocs-material prints on every run. It is
# advocacy in an upstream governance dispute, not a problem with this build —
# mkdocs-material 9.x pins "mkdocs<2", so 2.0 can never land in our venv.
# The real date to care about is Material's EOL, 2026-11-05; see README.
$env:NO_MKDOCS_2_WARNING = 'true'

# Make a freshly-installed Doxygen visible without opening a new terminal.
$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
            [System.Environment]::GetEnvironmentVariable('Path','User')

Write-Host "== 1/3  Syncing design docs from /RawDocs ==" -ForegroundColor Cyan
& "$Root/sync-docs.ps1"

Write-Host "== 2/3  Generating C++ reference (Doxygen) ==" -ForegroundColor Cyan
if (-not (Get-Command doxygen -ErrorAction SilentlyContinue)) {
    throw "doxygen not found on PATH. Run ./setup.ps1 (and open a fresh terminal) first."
}
& "$Root/ensure-doxygen-header.ps1"
Push-Location $Root
try { doxygen Doxyfile } finally { Pop-Location }

Write-Host "== 3/3  Building MkDocs site ==" -ForegroundColor Cyan
if (-not (Test-Path "$Root/.venv/Scripts/mkdocs.exe")) {
    throw "venv missing/broken (no mkdocs.exe). Recreate it: Remove-Item .venv -Recurse -Force; ./setup.ps1"
}
& "$Root/.venv/Scripts/mkdocs.exe" build -f "$Root/mkdocs.yml" --clean
if ($LASTEXITCODE -ne 0) { throw "mkdocs build failed (exit $LASTEXITCODE)." }

Write-Host ""
Write-Host "Built static site: $Root\site\index.html" -ForegroundColor Green
