# Dark Tower wiki — full static build into Wiki/site/.
# Steps: sync design docs -> run Doxygen -> build MkDocs site.

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
$Repo = Split-Path -Parent $Root

# Make a freshly-installed Doxygen visible without opening a new terminal.
$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
            [System.Environment]::GetEnvironmentVariable('Path','User')

Write-Host "== 1/3  Syncing design docs from /Docs ==" -ForegroundColor Cyan
$design = Join-Path $Root "docs/design"
New-Item -ItemType Directory -Force -Path $design | Out-Null
Get-ChildItem -Path $design -File | Where-Object Name -ne '.gitkeep' | Remove-Item -Force
Copy-Item (Join-Path $Root "RawDocs/*.md") $design
Write-Host "   $((Get-ChildItem $design -Filter *.md).Count) design page(s) synced."

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
