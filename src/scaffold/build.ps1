#!/usr/bin/env pwsh
# One command for the whole pipeline: convert raw/ -> ingest via Sunny -> archive.
# Usage:
#   ./tools/build.ps1            # convert, ingest, then archive automatically
#   ./tools/build.ps1 -Review    # convert and ingest, but STOP before archiving
#   ./tools/build.ps1 -SunnyCmd opencode

param(
    [switch]$Review,
    [string]$SunnyCmd = "sunny"
)

$ErrorActionPreference = "Stop"

Write-Host "=== LLM Wiki — Build (convert -> ingest -> archive) ===" -ForegroundColor Cyan
Write-Host ""

# 1. Convert raw/ -> inbox/
Write-Host "[1/3] Converting raw/ to markdown..." -ForegroundColor Yellow
& "$PSScriptRoot\convert-all.ps1"
Write-Host ""

# 2. Ingest inbox/ via Sunny
Write-Host "[2/3] Ingesting via Sunny..." -ForegroundColor Yellow
& "$PSScriptRoot\ingest.ps1" -SunnyCmd $SunnyCmd
$ingestExit = $LASTEXITCODE
Write-Host ""

if ($ingestExit -ne 0) {
    Write-Host "Ingest did not complete cleanly (exit $ingestExit). Skipping archive." -ForegroundColor Red
    Write-Host "Review the output, then archive manually: ./tools/mark-all-processed.ps1" -ForegroundColor Yellow
    exit $ingestExit
}

# 3. Archive (unless reviewing first)
if ($Review) {
    Write-Host "[3/3] -Review set: stopping before archive." -ForegroundColor Yellow
    Write-Host "Check the new pages in Obsidian, then run: ./tools/mark-all-processed.ps1" -ForegroundColor White
    exit 0
}

Write-Host "[3/3] Archiving the queue..." -ForegroundColor Yellow
& "$PSScriptRoot\mark-all-processed.ps1"
Write-Host ""
Write-Host "=== Build complete ===" -ForegroundColor Green
