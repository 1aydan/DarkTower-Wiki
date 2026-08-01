# Dark Tower wiki — local live preview at http://127.0.0.1:8000
# Syncs design docs + regenerates the Doxygen reference, then serves with reload.
# Re-run this after changing code comments or Doxygen settings to refresh the API.

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot

# See build.ps1 — suppresses mkdocs-material's MkDocs 2.0 advocacy banner.
$env:NO_MKDOCS_2_WARNING = 'true'

# Make a freshly-installed Doxygen visible without opening a new terminal.
$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
            [System.Environment]::GetEnvironmentVariable('Path','User')

Write-Host "== Syncing design docs ==" -ForegroundColor Cyan
& "$Root/sync-docs.ps1"

Write-Host "== Generating C++ reference (Doxygen) ==" -ForegroundColor Cyan
if (Get-Command doxygen -ErrorAction SilentlyContinue) {
    & "$Root/ensure-doxygen-header.ps1"
    Push-Location $Root
    try { doxygen Doxyfile } finally { Pop-Location }
} else {
    Write-Host "   doxygen not on PATH — serving without the Code Reference (run ./setup.ps1)." -ForegroundColor Yellow
}

Write-Host "== Serving (Ctrl+C to stop) ==" -ForegroundColor Cyan
& "$Root/.venv/Scripts/mkdocs.exe" serve -f "$Root/mkdocs.yml"
