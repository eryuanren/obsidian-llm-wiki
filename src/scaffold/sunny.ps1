#!/usr/bin/env pwsh
# Sunny CLI wrapper for the LLM Wiki.
# Usage:
#   ./tools/sunny.ps1 -Ingest                 # ingest everything in inbox/
#   ./tools/sunny.ps1 -Status                 # wiki stats + recent activity
#   ./tools/sunny.ps1 -Prompt "lint the wiki" # send a custom prompt to Sunny

param(
    [switch]$Build,
    [switch]$Ingest,
    [switch]$Status,
    [string]$Prompt,
    [string]$SunnyCmd = "sunny"
)

$ErrorActionPreference = "Stop"
$WikiRoot = (Resolve-Path "$PSScriptRoot\..").Path

if (!$Build -and !$Ingest -and !$Status -and !$Prompt) {
    Write-Host @"
=== LLM Wiki — Sunny CLI ===

  ./tools/sunny.ps1 -Build                   Full pipeline: convert raw/ -> ingest -> archive
  ./tools/sunny.ps1 -Ingest                  Ingest everything queued in inbox/
  ./tools/sunny.ps1 -Status                  Show wiki stats and recent activity
  ./tools/sunny.ps1 -Prompt "<message>"      Send a custom prompt to Sunny

Examples:
  ./tools/sunny.ps1 -Build
  ./tools/sunny.ps1 -Prompt "lint the wiki"
"@
    exit 0
}

if ($Build) {
    & "$PSScriptRoot\build.ps1" -SunnyCmd $SunnyCmd
    exit $LASTEXITCODE
}

if ($Ingest) {
    & "$PSScriptRoot\ingest.ps1" -SunnyCmd $SunnyCmd
    exit $LASTEXITCODE
}

if ($Status) {
    Write-Host "=== LLM Wiki Status ===" -ForegroundColor Cyan
    Write-Host ""

    # Wiki page counts.
    $folders = [ordered]@{
        "Entities"  = "wiki/entities"
        "Concepts"  = "wiki/concepts"
        "Sources"   = "wiki/sources"
        "Synthesis" = "wiki/synthesis"
    }
    foreach ($kv in $folders.GetEnumerator()) {
        $path = Join-Path $WikiRoot $kv.Value
        $count = if (Test-Path $path) { (Get-ChildItem $path -Filter *.md -File).Count } else { 0 }
        Write-Host ("{0,-10}: {1} pages" -f $kv.Key, $count) -ForegroundColor Green
    }
    Write-Host ""

    # Queue state.
    $inbox = Join-Path $WikiRoot "inbox"
    $proc  = Join-Path $WikiRoot "processed"
    $inboxCount = if (Test-Path $inbox) { (Get-ChildItem $inbox -File | Where-Object { $_.Name -ne ".gitkeep" }).Count } else { 0 }
    $procCount  = if (Test-Path $proc)  { (Get-ChildItem $proc  -File | Where-Object { $_.Name -ne ".gitkeep" }).Count } else { 0 }
    Write-Host "Inbox (awaiting ingest): $inboxCount" -ForegroundColor Yellow
    Write-Host "Processed (archived):    $procCount" -ForegroundColor Gray
    Write-Host ""

    # Recent log entries (parseable by the documented prefix).
    $logPath = Join-Path $WikiRoot "wiki/log.md"
    if (Test-Path $logPath) {
        Write-Host "Recent activity:" -ForegroundColor Cyan
        $recent = Select-String -Path $logPath -Pattern '^## \[' | Select-Object -Last 5
        if ($recent) { $recent | ForEach-Object { Write-Host "  $($_.Line)" -ForegroundColor Gray } }
        else { Write-Host "  No activity yet" -ForegroundColor Gray }
    }
    exit 0
}

if ($Prompt) {
    $cmd = $SunnyCmd
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        if (Get-Command opencode -ErrorAction SilentlyContinue) { $cmd = "opencode" }
        else { Write-Host "Error: neither '$SunnyCmd' nor 'opencode' is on PATH." -ForegroundColor Red; exit 1 }
    }
    Write-Host "=== Sending to Sunny ($cmd) ===" -ForegroundColor Cyan
    Write-Host "Prompt: $Prompt`n" -ForegroundColor Yellow
    Push-Location $WikiRoot
    try { & $cmd run $Prompt } finally { Pop-Location }
    exit $LASTEXITCODE
}
