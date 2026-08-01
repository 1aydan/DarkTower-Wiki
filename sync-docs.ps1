# Syncs RawDocs/*.md into docs/design/ and regenerates the Design landing page.
# Shared by build.ps1 and serve.ps1 so both stay in step.
#
# docs/design/ is gitignored and fully regenerated here — never hand-edit it.
# To add a page: drop the .md into RawDocs/ and add one line to the nav in mkdocs.yml.

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot

$raw    = Join-Path $Root "RawDocs"
$design = Join-Path $Root "docs/design"

New-Item -ItemType Directory -Force -Path $design | Out-Null
Get-ChildItem -Path $design -File | Where-Object Name -ne '.gitkeep' | Remove-Item -Force
Copy-Item (Join-Path $raw "*.md") $design

# Card icon per page. Anything not listed falls back to a generic doc icon.
$icons = @{
    'CombatPipeline'                = 'material-sword-cross'
    'AbilityEventSystem'            = 'material-flash'
    'StatSystem'                    = 'material-chart-line'
    'Loot_and_Combat_Tuning_Guide'  = 'material-treasure-chest'
    'QuestSystem'                   = 'material-script-text'
    'SkillTreeTooltipAuthoring'     = 'material-file-tree'
    'SkillTreeSystemAudit'          = 'material-clipboard-check'
    'CheatCommands'                 = 'material-console'
}

# Card titles come from each page's H1. Override only where the H1 is too long
# to read well on a card, so the card and the nav label agree.
$titles = @{
    'Loot_and_Combat_Tuning_Guide' = 'Loot & Combat Tuning'
    'SkillTreeSystemAudit'         = 'Skill Tree — System Audit'
    'SkillTreeTooltipAuthoring'    = 'Skill Tree — Tooltip Authoring'
}

# Ordered to match the nav in mkdocs.yml; unlisted files are appended alphabetically.
$order = @(
    'CombatPipeline', 'AbilityEventSystem', 'StatSystem', 'Loot_and_Combat_Tuning_Guide',
    'QuestSystem', 'SkillTreeTooltipAuthoring', 'SkillTreeSystemAudit', 'CheatCommands'
)

$pages = Get-ChildItem $design -Filter *.md | Sort-Object {
    $i = $order.IndexOf($_.BaseName); if ($i -lt 0) { [int]::MaxValue } else { $i }
}, BaseName

$cards = foreach ($page in $pages) {
    $lines = Get-Content $page.FullName -Encoding UTF8

    # First ATX H1 becomes the card title; drop the shared "Dark Tower — " prefix.
    $title = ($lines | Where-Object { $_.TrimStart([char]0xFEFF, ' ') -match '^#\s+\S' } |
                Select-Object -First 1)
    $title = if ($titles.ContainsKey($page.BaseName)) {
        $titles[$page.BaseName]
    } elseif ($title) {
        ($title.TrimStart([char]0xFEFF, ' ') -replace '^#\s+', '' -replace '^Dark Tower\s+[—-]\s+', '').Trim()
    } else { $page.BaseName }

    # Blurb = the first real paragraph. The source docs hard-wrap, so join its
    # lines back together rather than taking a single (half-sentence) line.
    $para = [System.Collections.Generic.List[string]]::new()
    foreach ($line in $lines) {
        $text = $line.TrimStart([char]0xFEFF).Trim()
        if ($para.Count -eq 0) {
            # Skip headings, blockquotes/italic notes, tables and list items.
            if ($text -eq '' -or $text -match '^[#_>|*-]') { continue }
            $para.Add($text)
        }
        elseif ($text -eq '' -or $text -match '^[#>|]') { break }
        else { $para.Add($text) }
    }
    # Drop bold/italic markers — emphasis inside a card blurb just adds noise.
    $blurb = (($para -join ' ') -replace '\s+', ' ') -replace '\*+([^*]+)\*+', '$1'
    if ($blurb.Length -gt 170) {
        $blurb = ($blurb.Substring(0, 170) -replace '\s+\S*$', '') + '…'
    }
    # A paragraph that only introduces a list reads badly as a standalone blurb.
    $blurb = $blurb -replace ':$', '…'

    $icon = if ($icons.ContainsKey($page.BaseName)) { $icons[$page.BaseName] } else { 'material-file-document' }

    "- :$($icon): **[$title]($($page.Name))**"
    ""
    "    $blurb"
    ""
}

@(
    '# Design systems'
    ''
    "Plain-English guides to each Dark Tower system and the knobs designers can turn."
    'For the exact classes, tags and attributes behind them, see the'
    '[Code Reference](../api/index.html).'
    ''
    '<div class="grid cards" markdown>'
    ''
    $cards
    '</div>'
) | Set-Content (Join-Path $design "index.md") -Encoding UTF8

Write-Host "   $($pages.Count) design page(s) synced + landing page generated."
