# Dark Tower wiki — one-time toolchain setup.
# Installs MkDocs Material (into Wiki/.venv), Doxygen (via winget), and the
# doxygen-awesome-css theme. Re-running is safe; it skips what already exists.

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot

Write-Host "== 1/3  Python venv + MkDocs Material ==" -ForegroundColor Cyan
if (-not (Test-Path "$Root/.venv")) {
    python -m venv "$Root/.venv"
}
& "$Root/.venv/Scripts/python.exe" -m pip install --upgrade pip
& "$Root/.venv/Scripts/python.exe" -m pip install -r "$Root/requirements.txt"

Write-Host "== 2/3  Doxygen ==" -ForegroundColor Cyan
if (Get-Command doxygen -ErrorAction SilentlyContinue) {
    Write-Host "   Doxygen already on PATH: $((Get-Command doxygen).Source)"
} else {
    Write-Host "   Installing Doxygen via winget..."
    winget install --id DimitriVanHeesch.Doxygen -e --source winget --accept-source-agreements --accept-package-agreements
    # Refresh PATH from the registry so 'doxygen' works in THIS session (no new terminal).
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
                [System.Environment]::GetEnvironmentVariable('Path','User')
    if (-not (Get-Command doxygen -ErrorAction SilentlyContinue)) {
        Write-Host "   NOTE: open a fresh terminal for 'doxygen' to land on PATH, then re-run setup.ps1." -ForegroundColor Yellow
    }
}

Write-Host "== 3/3  doxygen-awesome-css theme ==" -ForegroundColor Cyan
$themeDir = "$Root/doxygen-awesome-css"
if (Test-Path "$themeDir/doxygen-awesome.css") {
    Write-Host "   Theme already present."
} else {
    $ver = "2.3.4"
    $zip = Join-Path $env:TEMP "doxygen-awesome-$ver.zip"
    $url = "https://github.com/jothepro/doxygen-awesome-css/archive/refs/tags/v$ver.zip"
    Write-Host "   Downloading $url"
    Invoke-WebRequest -Uri $url -OutFile $zip
    Expand-Archive -Path $zip -DestinationPath $env:TEMP -Force
    if (Test-Path $themeDir) { Remove-Item $themeDir -Recurse -Force }
    Move-Item (Join-Path $env:TEMP "doxygen-awesome-css-$ver") $themeDir
    Remove-Item $zip -Force
    Write-Host "   Theme installed to $themeDir"
}

Write-Host "== Dark-mode header for the code reference ==" -ForegroundColor Cyan
& "$Root/ensure-doxygen-header.ps1"

Write-Host ""
Write-Host "Setup complete. Next:  ./serve.ps1  (preview)  or  ./build.ps1  (static site)" -ForegroundColor Green
