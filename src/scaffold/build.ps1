#!/usr/bin/env pwsh
# One command for the whole pipeline: convert raw/ -> ingest via Sunny -> archive.
#
# The archive step files away only what Sunny marked done in
# .llm-wiki/ingest-status.json, so a partly-successful run archives the sources that
# made it into the wiki and leaves the rest in inbox/ for another pass.
#
# Usage:
#   ./tools/build.ps1            # convert, ingest, archive what succeeded
#   ./tools/build.ps1 -Review    # convert and ingest, but STOP before archiving
#   ./tools/build.ps1 -Auto      # auto-approve Sunny's file edits (unattended)
#   ./tools/build.ps1 -SunnyCmd opencode

param(
    [switch]$Review,
    [switch]$Auto,
    [switch]$Batch,
    [string]$SunnyCmd = ""
)

$ErrorActionPreference = "Stop"

Write-Host "=== LLM Wiki - Build (convert -> ingest -> archive) ===" -ForegroundColor Cyan
Write-Host ""

# 1. Convert raw/ -> inbox/
Write-Host "[1/3] Converting raw/ to markdown..." -ForegroundColor Yellow
& "$PSScriptRoot\convert-all.ps1"
Write-Host ""

# 2. Ingest inbox/ via Sunny
Write-Host "[2/3] Ingesting via Sunny..." -ForegroundColor Yellow
$ingestArgs = @{}
if ($SunnyCmd) { $ingestArgs["SunnyCmd"] = $SunnyCmd }
if ($Auto)     { $ingestArgs["Auto"] = $true }
if ($Batch)    { $ingestArgs["Batch"] = $true }
& "$PSScriptRoot\ingest.ps1" @ingestArgs
$ingestExit = $LASTEXITCODE
Write-Host ""

if ($ingestExit -ne 0) {
    Write-Host "Ingest reported problems (exit $ingestExit)." -ForegroundColor Yellow
    Write-Host "Archiving only what Sunny marked done; the rest stays in inbox/." -ForegroundColor Yellow
    Write-Host ""
}

# 3. Archive (unless reviewing first)
if ($Review) {
    Write-Host "[3/3] -Review set: stopping before archive." -ForegroundColor Yellow
    Write-Host "Check the new pages in Obsidian, then run: ./tools/mark-all-processed.ps1" -ForegroundColor White
    exit $ingestExit
}

Write-Host "[3/3] Archiving what was ingested..." -ForegroundColor Yellow
& "$PSScriptRoot\mark-all-processed.ps1"
Write-Host ""
Write-Host "=== Build complete ===" -ForegroundColor Green
exit $ingestExit
