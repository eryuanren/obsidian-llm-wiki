#!/usr/bin/env pwsh
# Ingest the items queued in inbox/ into the wiki by invoking Sunny (opencode).
# Markdown files are read as text; image files are attached with --file so Sunny's
# vision model can view them directly. Sunny follows the INGEST workflow in AGENTS.md.
# After you review the results, archive the queue with ./tools/mark-all-processed.ps1
#
# Usage:
#   ./tools/ingest.ps1                 # ingest everything in inbox/
#   ./tools/ingest.ps1 -File foo.md    # ingest a single queued file
#   ./tools/ingest.ps1 -DryRun         # print the prompt, don't call Sunny
#   ./tools/ingest.ps1 -SunnyCmd opencode

param(
    [string]$File,
    [switch]$DryRun,
    [string]$SunnyCmd  = "sunny",   # the CLI command (sunny == opencode)
    [string]$WikiRoot  = "$PSScriptRoot\..",
    [string]$InboxPath = "$PSScriptRoot\..\inbox"
)

$ErrorActionPreference = "Stop"
$WikiRoot  = (Resolve-Path $WikiRoot).Path
$InboxPath = (Resolve-Path $InboxPath).Path
$imageExts = @(".png", ".jpg", ".jpeg", ".gif", ".webp", ".bmp", ".tif", ".tiff")

Write-Host "=== LLM Wiki — Ingest ===" -ForegroundColor Cyan

# 1. Determine which queued items to ingest.
if ($File) {
    $items = @(Get-Item (Join-Path $InboxPath ([System.IO.Path]::GetFileName($File))))
} else {
    if (!(Test-Path $InboxPath)) { Write-Host "No inbox/ folder found." -ForegroundColor Red; exit 1 }
    $items = Get-ChildItem -Path $InboxPath -File | Where-Object { $_.Name -ne ".gitkeep" }
}

if (!$items -or $items.Count -eq 0) {
    Write-Host "inbox/ is empty — nothing to ingest. Run ./tools/convert-all.ps1 first." -ForegroundColor Green
    exit 0
}

$images = @($items | Where-Object { $imageExts -contains $_.Extension.ToLower() })
$docs   = @($items | Where-Object { $imageExts -notcontains $_.Extension.ToLower() })

Write-Host "Files to ingest ($($items.Count)):" -ForegroundColor Cyan
$docs   | ForEach-Object { Write-Host "  - inbox/$($_.Name)" }
$images | ForEach-Object { Write-Host "  - inbox/$($_.Name)  [image]" }
Write-Host ""

# 2. Build the prompt. Detailed rules live in AGENTS.md, loaded from the wiki root.
$lines = @()
$docs   | ForEach-Object { $lines += "- inbox/$($_.Name)" }
$images | ForEach-Object { $lines += "- inbox/$($_.Name) (image)" }
$fileLines = $lines -join "`n"

$imgNote = ""
if ($images.Count -gt 0) {
    $imgNote = "`n`nThe image item(s) above are image files in inbox/. Open each one by its" +
               " path with your read tool to view it (you are multimodal). Treat each standalone" +
               " image as its own source: write a source page describing what it shows (text," +
               " data, diagram contents, key values), and embed the original with ![[filename]]" +
               " so it can be re-examined later."
}

$prompt = @"
Ingest the following items into the wiki, following the INGEST workflow in AGENTS.md.

Items:
$fileLines

For each: read it (or view it, if an image), check wiki/processed.md, write a source
page, create/update the relevant entity and concept pages, add [[links]] both ways,
update wiki/index.md, and append an entry to wiki/log.md using the documented prefix
format. Do not modify raw/. When finished, report pages created, pages updated,
contradictions found, and any suggested synthesis pages.$imgNote
"@

if ($DryRun) {
    Write-Host "----- PROMPT (dry run) -----" -ForegroundColor DarkGray
    Write-Host $prompt
    exit 0
}

# 3. Resolve the CLI command (prefer 'sunny', fall back to 'opencode').
$cmd = $SunnyCmd
if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
    if (Get-Command opencode -ErrorAction SilentlyContinue) {
        $cmd = "opencode"
        Write-Host "'$SunnyCmd' not found; using 'opencode'." -ForegroundColor Yellow
    } else {
        Write-Host "Error: neither '$SunnyCmd' nor 'opencode' is on PATH." -ForegroundColor Red
        Write-Host "`nCopy this prompt into Sunny manually (attach the images yourself):" -ForegroundColor Yellow
        Write-Host "------------------------------------------------------------"
        Write-Host $prompt
        Write-Host "------------------------------------------------------------"
        exit 1
    }
}

# 4. Run Sunny headlessly from the wiki root so relative paths resolve and AGENTS.md loads.
# The prompt is the only positional arg; images are opened by Sunny's read tool (passing
# them as --file attachments makes opencode treat the prompt itself as a file path).
Write-Host "Calling '$cmd run' from $WikiRoot ..." -ForegroundColor Yellow
Write-Host ""
Push-Location $WikiRoot
try {
    & $cmd run $prompt
    $exit = $LASTEXITCODE
} finally {
    Pop-Location
}

Write-Host ""
if ($exit -eq 0) {
    Write-Host "=== Sunny finished ===" -ForegroundColor Green
    Write-Host "1. Review the new/updated pages in Obsidian." -ForegroundColor White
    Write-Host "2. Archive the queue:  ./tools/mark-all-processed.ps1" -ForegroundColor White
} else {
    Write-Host "Sunny exited with code $exit — review output above before archiving." -ForegroundColor Red
}
