#!/usr/bin/env pwsh
# Archive every markdown file currently in inbox/: move to processed/ and record each
# in wiki/processed.md. Run after Sunny has ingested the queue and you've reviewed it.
# Usage: ./tools/mark-all-processed.ps1 [notes]

param(
    [string]$Notes = "",
    [string]$InboxPath = "$PSScriptRoot\..\inbox"
)

$ErrorActionPreference = "Stop"

$files = Get-ChildItem -Path $InboxPath -File | Where-Object { $_.Name -ne ".gitkeep" }

if (!$files -or $files.Count -eq 0) {
    Write-Host "inbox/ has nothing to archive." -ForegroundColor Green
    exit 0
}

Write-Host "Archiving $($files.Count) file(s) from inbox/ to processed/..." -ForegroundColor Cyan
foreach ($f in $files) {
    & "$PSScriptRoot\mark-processed.ps1" -File $f.Name -Notes $Notes
}
Write-Host "`nDone." -ForegroundColor Cyan
