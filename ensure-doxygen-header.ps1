# Ensures Wiki/header.html exists for the doxygen-awesome dark-mode toggle.
# Generates the default Doxygen header once (matching the installed Doxygen
# version) and injects the awesome-css init scripts before </head>.
# Called by setup.ps1 / build.ps1 / serve.ps1. Pass -Force to regenerate.

param([switch]$Force)
$ErrorActionPreference = 'Stop'
$Root   = $PSScriptRoot
$header = Join-Path $Root 'header.html'

if ((Test-Path $header) -and -not $Force) { return }

if (-not (Get-Command doxygen -ErrorAction SilentlyContinue)) {
    Write-Host "   (dark-mode header skipped: doxygen not on PATH yet — re-run after setup)" -ForegroundColor Yellow
    return
}

Push-Location $Root
try {
    $tmpFooter = Join-Path $Root '.doxy_footer_tmp.html'
    $tmpCss    = Join-Path $Root '.doxy_style_tmp.css'
    doxygen -w html $header $tmpFooter $tmpCss | Out-Null
    Remove-Item $tmpFooter, $tmpCss -Force -ErrorAction SilentlyContinue

    # Literal here-string: $relpath^ must reach Doxygen un-expanded by PowerShell.
    $inject = @'
<script type="text/javascript" src="$relpath^doxygen-awesome-darkmode-toggle.js"></script>
<script type="text/javascript" src="$relpath^doxygen-awesome-fragment-copy-button.js"></script>
<script type="text/javascript" src="$relpath^doxygen-awesome-paragraph-link.js"></script>
<script type="text/javascript">
    DoxygenAwesomeDarkModeToggle.init()
    DoxygenAwesomeFragmentCopyButton.init()
    DoxygenAwesomeParagraphLink.init()
</script>
</head>
'@
    $content = Get-Content $header -Raw
    if ($content -notmatch 'DoxygenAwesomeDarkModeToggle') {
        # .Replace() is literal — avoids regex treating $ in $relpath as a backref.
        $content = $content.Replace('</head>', $inject)
        Set-Content $header $content -Encoding UTF8
    }
    Write-Host "   Dark-mode header ready: header.html" -ForegroundColor Green
}
finally { Pop-Location }
