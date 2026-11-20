#!/usr/bin/env pwsh
# Archive the files Sunny actually ingested: move them from inbox/ to processed/ and
# record each in wiki/processed.md.
#
# Only files Sunny marked "done" in .llm-wiki/ingest-status.json are archived. A clean
# exit code from the CLI means the agent finished its turn, not that every file was
# ingested - archiving on the exit code alone quietly buries the ones it skipped.
#
# Usage:
#   ./tools/mark-all-processed.ps1              # archive everything marked done
#   ./tools/mark-all-processed.ps1 -Force       # archive the whole queue regardless
#   ./tools/mark-all-processed.ps1 "notes"

param(
    [string]$Notes = "",
    [switch]$Force,
    [string]$WikiRoot  = "$PSScriptRoot\..",
    [string]$InboxPath = "$PSScriptRoot\..\inbox"
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\_common.ps1"

$WikiRoot = (Resolve-Path $WikiRoot).Path

$files = Get-ChildItem -Path $InboxPath -File | Where-Object { $_.Name -ne ".gitkeep" }

if (!$files -or $files.Count -eq 0) {
    Write-Host "inbox/ has nothing to archive." -ForegroundColor Green
    exit 0
}

$status = Read-IngestStatus -WikiRoot $WikiRoot

if ($status.Count -eq 0 -and -not $Force) {
    Write-Host "No ingest status recorded in .llm-wiki/ingest-status.json." -ForegroundColor Yellow
    Write-Host "Nothing archived. Run ./tools/ingest.ps1 first, or force it:" -ForegroundColor Yellow
    Write-Host "  ./tools/mark-all-processed.ps1 -Force" -ForegroundColor Gray
    exit 1
}

$archived = 0
$held = @()

foreach ($f in $files) {
    $entry = $status[$f.Name]
    $state = if ($entry -and $entry.status) { [string]$entry.status } else { "" }

    if ($Force -or $state -eq "done") {
        $note = $Notes
        if (-not $note -and $entry -and $entry.note) { $note = [string]$entry.note }
        & "$PSScriptRoot\mark-processed.ps1" -File $f.Name -Notes $note -WikiRoot $WikiRoot
        $archived++
    } else {
        $held += [PSCustomObject]@{
            Name   = $f.Name
            Reason = if ($state) { $state } else { "no status recorded" }
            Note   = if ($entry -and $entry.note) { [string]$entry.note } else { "" }
        }
    }
}

Write-Host ""
Write-Host "Archived $archived file(s)." -ForegroundColor Cyan

if ($held.Count -gt 0) {
    Write-Host "Left in inbox/ ($($held.Count)):" -ForegroundColor Yellow
    foreach ($h in $held) {
        $suffix = if ($h.Note) { " - $($h.Note)" } else { "" }
        Write-Host "  - $($h.Name) [$($h.Reason)]$suffix" -ForegroundColor Gray
    }
    Write-Host "Re-run ./tools/ingest.ps1 for these, or archive anyway with -Force." -ForegroundColor Gray
}
