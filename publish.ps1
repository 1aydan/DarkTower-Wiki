# Dark Tower wiki — build + publish the static site to GitHub Pages.
# Pushes the freshly built Wiki/site/ to the 'gh-pages' branch of 'origin'.
#
# Prereqs (one-time): Wiki/ is a git repo with an 'origin' remote pointing at
# your GitHub wiki repo, and Pages is set to serve from the 'gh-pages' branch.
# Run from Wiki/.

param(
    [string]$Message = "Publish wiki $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
)
$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot

Write-Host "== Building static site ==" -ForegroundColor Cyan
& "$Root/build.ps1"

Push-Location $Root
try {
    git rev-parse --is-inside-work-tree *> $null
    if ($LASTEXITCODE -ne 0) {
        throw "Wiki/ is not a git repo yet. One-time setup:`n" +
              "  git init`n  git add -A`n  git commit -m 'wiki sources'`n" +
              "  git remote add origin <your-github-repo-url>"
    }
    $origin = git remote get-url origin 2>$null
    if (-not $origin) {
        throw "No 'origin' remote. Add it:  git remote add origin <your-github-repo-url>"
    }
    Write-Host "== Publishing site/ -> $origin (branch: gh-pages) ==" -ForegroundColor Cyan
    # -n adds .nojekyll (so Doxygen/_-prefixed files aren't mangled by Jekyll),
    # -p pushes, -f forces, -m sets the commit message.
    & "$Root/.venv/Scripts/ghp-import.exe" -n -p -f -m $Message site
}
finally { Pop-Location }

Write-Host ""
Write-Host "Published. GitHub Pages usually updates within ~1 minute." -ForegroundColor Green
